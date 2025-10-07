package main

import (
	context "context"
	log "log"
	os "os"
	"google.golang.org/grpc"
	pb "server_streaming/greetstream"
)

func main() {
	conn, err := grpc.Dial("localhost:50052", grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewGreeterClient(conn)

	name := "World"
	if len(os.Args) > 1 {
		name = os.Args[1]
	}

	stream, err := c.ListGreetings(context.Background(), &pb.GreetRequest{Name: name})
	if err != nil {
		log.Fatalf("could not start stream: %v", err)
	}
	for {
		reply, err := stream.Recv()
		if err != nil {
			break
		}
		log.Printf("Greeting: %s", reply.Message)
	}
}
