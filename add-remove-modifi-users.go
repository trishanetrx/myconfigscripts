package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func main() {
	for {
		fmt.Println("1. List all users")
		fmt.Println("2. Add a user")
		fmt.Println("3. Remove a user")
		fmt.Println("4. Modify user permissions")
		fmt.Println("5. Exit")
		fmt.Print("Choose an option: ")

		var choice int
		fmt.Scan(&choice)

		switch choice {
		case 1:
			listUsers()
		case 2:
			addUser()
		case 3:
			removeUser()
		case 4:
			modifyUserPermissions()
		case 5:
			os.Exit(0)
		default:
			fmt.Println("Invalid option. Please try again.")
		}
	}
}

func listUsers() {
	cmd := exec.Command("cut", "-d:", "-f1", "/etc/passwd")
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Error listing users:", err)
		return
	}

	users := strings.Split(string(output), "\n")
	for _, user := range users {
		if user != "" {
			fmt.Println(user)
		}
	}
}

func addUser() {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter username to add: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	cmd := exec.Command("sudo", "adduser", "--disabled-password", "--gecos", "", username)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println("Error adding user:", err)
		return
	}

	fmt.Print("Enter password for new user: ")
	password, _ := reader.ReadString('\n')
	password = strings.TrimSpace(password)

	cmd = exec.Command("sudo", "chpasswd")
	cmd.Stdin = strings.NewReader(fmt.Sprintf("%s:%s", username, password))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println("Error setting password for user:", err)
	}
}

func removeUser() {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter username to remove: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	cmd := exec.Command("sudo", "deluser", username)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println("Error removing user:", err)
	}
}

func modifyUserPermissions() {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter username to modify: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	fmt.Println("1. Add to group")
	fmt.Println("2. Remove from group")
	fmt.Print("Choose an option: ")
	var choice int
	fmt.Scan(&choice)

	switch choice {
	case 1:
		fmt.Print("Enter group name to add the user to: ")
		group, _ := reader.ReadString('\n')
		group = strings.TrimSpace(group)
		cmd := exec.Command("sudo", "usermod", "-aG", group, username)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		if err := cmd.Run(); err != nil {
			fmt.Println("Error adding user to group:", err)
		}
	case 2:
		fmt.Print("Enter group name to remove the user from: ")
		group, _ := reader.ReadString('\n')
		group = strings.TrimSpace(group)
		cmd := exec.Command("sudo", "gpasswd", "-d", username, group)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		if err := cmd.Run(); err != nil {
			fmt.Println("Error removing user from group:", err)
		}
	default:
		fmt.Println("Invalid option. Please try again.")
	}
}
