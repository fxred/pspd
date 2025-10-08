package main

import (
	fmt "fmt"
	log "log"
	net "net"
	"time"

	"google.golang.org/grpc"
	pb "server_streaming/greetstream"
)

type server struct {
	pb.UnimplementedGreeterServer
}

func (s *server) ListGreetings(req *pb.GreetRequest, stream pb.Greeter_ListGreetingsServer) error {
       for i := 1; i <= 5; i++ {
	       log.Printf("Sending message %d to client: %s", i, req.Name)
	       msg := fmt.Sprintf("Hello %s! (message %d)", req.Name, i)
	       if err := stream.Send(&pb.GreetReply{Message: msg}); err != nil {
		       return err
	       }
	       time.Sleep(1 * time.Second)
       }
       return nil
}

func main() {
	lis, err := net.Listen("tcp", ":50052")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterGreeterServer(s, &server{})
	log.Println("gRPC server streaming listening on :50052")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
