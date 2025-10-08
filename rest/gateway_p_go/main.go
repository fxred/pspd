package main

import (
	"bytes"
	"io"
	"net/http"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

var (
	serviceA_URL = getenvDefault("SERVICE_A_URL", "http://service-a:3002")
	serviceB_URL = getenvDefault("SERVICE_B_URL", "http://service-b:3001")
)

func getenvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func proxyRequest(c *gin.Context, targetURL string) {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read request body"})
		return
	}

	fullTargetURL := targetURL + c.Request.URL.RequestURI()

	proxyReq, err := http.NewRequest(c.Request.Method, fullTargetURL, bytes.NewReader(body))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create proxy request"})
		return
	}

	proxyReq.Header = c.Request.Header.Clone()

	client := &http.Client{}
	resp, err := client.Do(proxyReq)
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Failed to connect to backend service"})
		return
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read response from backend service"})
		return
	}

	for key, values := range resp.Header {
		if key == "Access-Control-Allow-Origin" || key == "Access-Control-Allow-Methods" {
			continue
		}
		for _, value := range values {
			c.Writer.Header().Add(key, value)
		}
	}

	c.Data(resp.StatusCode, resp.Header.Get("Content-Type"), responseBody)
}

func main() {
	router := gin.Default()
	router.Use(cors.Default())

	router.POST("/game/join", func(c *gin.Context) {
		proxyRequest(c, serviceB_URL)
	})

	router.GET("/game/state", func(c *gin.Context) {
		proxyRequest(c, serviceB_URL)
	})

	router.POST("/game/move", func(c *gin.Context) {
		proxyRequest(c, serviceA_URL)
	})

	println("Gateway P (Go) rodando em http://127.0.0.1:8000")
	router.Run(":8000")
}
