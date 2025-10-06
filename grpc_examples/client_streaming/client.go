package main

import (
	log "log"
	os "os"
	"google.golang.org/grpc"
	pb "client_streaming/greetcstream"
	"context"
)

func main() {
	conn, err := grpc.Dial("localhost:50053", grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewGreeterClient(conn)

	stream, err := c.SendGreetings(context.Background())
	if err != nil {
		log.Fatalf("could not start stream: %v", err)
	}

	names := []string{"Alice", "Bob", "Carol"}
	if len(os.Args) > 1 {
		names = os.Args[1:]
	}

	for _, name := range names {
		if err := stream.Send(&pb.GreetRequest{Name: name}); err != nil {
			log.Fatalf("could not send name: %v", err)
		}
		log.Printf("Sent name: %s", name)
	}

	reply, err := stream.CloseAndRecv()
	if err != nil {
		log.Fatalf("could not receive reply: %v", err)
	}
	log.Printf("Server summary: %s", reply.Summary)
}
