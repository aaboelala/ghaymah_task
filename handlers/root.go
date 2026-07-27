package handlers

import "github.com/gofiber/fiber/v2"

// Welcome returns a greeting message for the root endpoint.
func Welcome(c *fiber.Ctx) error {
	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Welcome to Ghaymah SRE API",
	})
}
