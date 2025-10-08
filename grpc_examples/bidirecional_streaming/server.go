package main

import (
	io "io"
	log "log"
	net "net"

	"google.golang.org/grpc"
	pb "bidirecional_streaming/greetbistream"
)


type chatClient struct {
       stream pb.Greeter_ChatServer
       send   chan *pb.ChatMessage
}

type server struct {
       pb.UnimplementedGreeterServer
       clients map[*chatClient]struct{}
       register   chan *chatClient
       unregister chan *chatClient
       broadcast  chan *pb.ChatMessage
}

func newServer() *server {
       s := &server{
	       clients:    make(map[*chatClient]struct{}),
	       register:   make(chan *chatClient),
	       unregister: make(chan *chatClient),
	       broadcast:  make(chan *pb.ChatMessage),
       }
       go s.run()
       return s
}

func (s *server) run() {
       type broadcastMsg struct {
	       msg    *pb.ChatMessage
	       sender *chatClient
       }

       // Redefine s.broadcast to be of type chan broadcastMsg
       broadcast := make(chan broadcastMsg)
       s.broadcast = nil // unused, just for compatibility

       go func() {
	       for {
		       select {
		       case client := <-s.register:
			       s.clients[client] = struct{}{}
		       case client := <-s.unregister:
			       delete(s.clients, client)
			       close(client.send)
		       case b := <-broadcast:
			       for client := range s.clients {
				       if client == b.sender {
					       continue // não envie de volta para quem enviou
				       }
				       select {
				       case client.send <- b.msg:
				       default:
					       // Drop message if client is not ready
				       }
			       }
		       }
	       }
       }()

       // substitui o select principal por um bloqueio infinito
       select {}
}

func (s *server) Chat(stream pb.Greeter_ChatServer) error {
       client := &chatClient{
	       stream: stream,
	       send:   make(chan *pb.ChatMessage, 10),
       }
       s.register <- client
       defer func() { s.unregister <- client }()

       // Goroutine to send messages to this client
       go func() {
	       for msg := range client.send {
		       if err := client.stream.Send(msg); err != nil {
			       return
		       }
	       }
       }()

       // Canal para broadcast com referência ao remetente
       type broadcastMsg struct {
	       msg    *pb.ChatMessage
	       sender *chatClient
       }
       broadcast := make(chan broadcastMsg)

       // Goroutine para gerenciar o broadcast
       go func() {
	       for {
		       select {
		       case b := <-broadcast:
			       for c := range s.clients {
				       if c == b.sender {
					       continue
				       }
				       select {
				       case c.send <- b.msg:
				       default:
				       }
			       }
		       }
	       }
       }()

       // Receive messages from this client and broadcast
       for {
	       msg, err := stream.Recv()
	       if err == io.EOF {
		       return nil
	       }
	       if err != nil {
		       return err
	       }
	       log.Printf("Received from %s: %s", msg.Sender, msg.Message)
	       broadcast <- broadcastMsg{
		       msg: &pb.ChatMessage{
			       Sender:  msg.Sender,
			       Message: msg.Sender + ": " + msg.Message,
		       },
		       sender: client,
	       }
       }
}

func main() {
       lis, err := net.Listen("tcp", ":50054")
       if err != nil {
	       log.Fatalf("failed to listen: %v", err)
       }
       s := grpc.NewServer()
       pb.RegisterGreeterServer(s, newServer())
       log.Println("gRPC bidirectional streaming server listening on :50054")
       if err := s.Serve(lis); err != nil {
	       log.Fatalf("failed to serve: %v", err)
       }
}
