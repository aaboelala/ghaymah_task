package handlers

import (
	"github.com/gofiber/fiber/v2"

	"ghaymah-sre-api/metrics"
)

// GetMetrics returns a handler function that responds with current system metrics.
func GetMetrics(tracker *metrics.Tracker) fiber.Handler {
	return func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(tracker.GetMetrics())
	}
}
