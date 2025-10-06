package main

import (
	io "io"
	log "log"
	net "net"
	"fmt"

	"google.golang.org/grpc"
	pb "bidirecional_streaming/greetbistream"
)

type server struct {
	pb.UnimplementedGreeterServer
}

func (s *server) Chat(stream pb.Greeter_ChatServer) error {
	for {
		msg, err := stream.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		log.Printf("Received from %s: %s", msg.Sender, msg.Message)
		response := &pb.ChatMessage{
			Sender:  "Server",
			Message: fmt.Sprintf("Hello %s, you said: %s", msg.Sender, msg.Message),
		}
		if err := stream.Send(response); err != nil {
			return err
		}
	}
}

func main() {
	lis, err := net.Listen("tcp", ":50054")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterGreeterServer(s, &server{})
	log.Println("gRPC bidirectional streaming server listening on :50054")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
