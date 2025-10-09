package main

import (
    "fmt"

    "github.com/spf13/cobra"
)

func main() {
    var verbose bool

    rootCmd := &cobra.Command{
        Use:   "greeter",
        Short: "Simple greeting CLI",
        RunE: func(cmd *cobra.Command, args []string) error {
            if verbose {
                fmt.Println("Verbose mode enabled")
            }
            fmt.Println("Hello from Cobra!")
            return nil
        },
    }

    rootCmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "enable verbose output")

    if err := rootCmd.Execute(); err != nil {
        panic(err)
    }
}
