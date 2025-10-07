package main

import (
	bufio "bufio"
	log "log"
	os "os"
	"google.golang.org/grpc"
	pb "bidirecional_streaming/greetbistream"
	"context"
)

func main() {
	conn, err := grpc.Dial("localhost:50054", grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewGreeterClient(conn)

	stream, err := c.Chat(context.Background())
	if err != nil {
		log.Fatalf("could not start chat: %v", err)
	}

	go func() {
		scanner := bufio.NewScanner(os.Stdin)
		log.Print("Type your name and message (format: name: message): ")
		for {
			if !scanner.Scan() {
				break
			}
			input := scanner.Text()
			var name, message string
			sep := ": "
			if n := len(input); n > 0 {
				for i := 0; i < n-1; i++ {
					if input[i:i+2] == sep {
						name = input[:i]
						message = input[i+2:]
						break
					}
				}
			}
			if name == "" || message == "" {
				log.Println("Invalid input. Use: name: message")
				continue
			}
			if err := stream.Send(&pb.ChatMessage{Sender: name, Message: message}); err != nil {
				log.Fatalf("could not send message: %v", err)
			}
		}
		stream.CloseSend()
	}()

	for {
		resp, err := stream.Recv()
		if err != nil {
			break
		}
		log.Printf("Server: %s", resp.Message)
	}
}
