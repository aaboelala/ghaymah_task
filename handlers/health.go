package handlers

import (
	"time"

	"github.com/gofiber/fiber/v2"
)

// HealthCheck returns health status and current UTC timestamp.
func HealthCheck(c *fiber.Ctx) error {
	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"status":    "healthy",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}
