FROM golang:1.25 AS builder

WORKDIR /app

COPY gateway_p_go/go.mod gateway_p_go/go.sum ./

RUN go mod download

COPY gateway_p_go/. .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o gateway_go .

FROM alpine

COPY --from=builder /app/gateway_go /usr/local/bin/gateway_go

EXPOSE 8000

CMD ["/usr/local/bin/gateway_go"]