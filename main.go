package main

import (
	"log"
	"time"

	"github.com/gofiber/fiber/v2"

	"ghaymah-sre-api/handlers"
	"ghaymah-sre-api/metrics"
)

func main() {
	// Initialize thread-safe metrics tracker
	tracker := metrics.NewTracker()

	// Initialize Fiber app
	app := fiber.New()

	// Record start time, execute request, and update metrics
	app.Use(func(c *fiber.Ctx) error {
		start := time.Now()
		err := c.Next()
		tracker.RecordRequest(time.Since(start))
		return err
	})

	// Endpoints
	app.Get("/", handlers.Welcome)
	app.Get("/health", handlers.HealthCheck)
	app.Get("/metrics", handlers.GetMetrics(tracker))

	// Listen on port 8080
	log.Fatal(app.Listen(":8080"))
}
