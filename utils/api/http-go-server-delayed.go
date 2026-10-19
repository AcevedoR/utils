package main

import (
	"flag"
	"fmt"
	"net/http"
	"strconv"
	"time"
)

func main() {
	// Default delay in milliseconds, passed via flag
	defaultDelay := flag.Int("delay", 1, "Default delay in milliseconds before responding")
	port := flag.Int("port", 8080, "Port to run the server on")
	flag.Parse()

	http.HandleFunc("/delayed", func(w http.ResponseWriter, r *http.Request) {
		// Check query param ?ms=
		delay := *defaultDelay
		if msStr := r.URL.Query().Get("ms"); msStr != "" {
			if ms, err := strconv.Atoi(msStr); err == nil && ms >= 0 {
				delay = ms
			}
		}

		// Sleep
		time.Sleep(time.Duration(delay) * time.Millisecond)

		// Respond
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(fmt.Sprintf("Response after %d ms\n", delay)))
	})

	addr := fmt.Sprintf(":%d", *port)
	fmt.Printf("Server running on %s with default %d ms delay\n", addr, *defaultDelay)
	fmt.Printf("Usage: GET localhost:%d/delayed?ms=1000\n", *port)
	if err := http.ListenAndServe(addr, nil); err != nil {
		panic(err)
	}
}
