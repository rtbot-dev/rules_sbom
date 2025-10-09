package main

import (
	"fmt"

	"github.com/google/uuid"
)

func main() {
	fmt.Println("hello from Go", uuid.NewString())
}
