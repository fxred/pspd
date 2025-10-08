package main

import (
	fmt "fmt"
	io "io"
	log "log"
	net "net"

	"google.golang.org/grpc"
	pb "client_streaming/greetcstream"
)

type server struct {
	pb.UnimplementedGreeterServer
}

func (s *server) SendGreetings(stream pb.Greeter_SendGreetingsServer) error {
	names := []string{}
	for {
		req, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		log.Printf("Received name: %s", req.Name)
		names = append(names, req.Name)
	}
	summary := fmt.Sprintf("Received %d names: %v", len(names), names)
	return stream.SendAndClose(&pb.GreetReply{Summary: summary})
}

func main() {
	lis, err := net.Listen("tcp", ":50053")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterGreeterServer(s, &server{})
	log.Println("gRPC client streaming server listening on :50053")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
