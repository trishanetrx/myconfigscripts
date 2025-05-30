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
		fmt.Println("\n1. List all users")
		fmt.Println("2. Add a user")
		fmt.Println("3. Remove a user")
		fmt.Println("4. Modify user permissions")
		fmt.Println("5. Exit")
		fmt.Println("6. Show user group info")
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
		case 6:
			showUserGroups()
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

	// Check if 'adduser' supports '--disabled-password'
	var cmd *exec.Cmd
	testCmd := exec.Command("adduser", "--help")
	output, err := testCmd.CombinedOutput()

	if err == nil && strings.Contains(string(output), "--disabled-password") {
		cmd = exec.Command("sudo", "adduser", "--disabled-password", "--gecos", "", username)
	} else {
		cmd = exec.Command("sudo", "useradd", "-m", username)
	}

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println("Error adding user:", err)
		return
	}

	fmt.Print("Enter password for new user: ")
	passwordReader := bufio.NewReader(os.Stdin)
	password, _ := passwordReader.ReadString('\n')
	password = strings.TrimSpace(password)

	cmd = exec.Command("sudo", "chpasswd")
	cmd.Stdin = strings.NewReader(fmt.Sprintf("%s:%s", username, password))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println("Error setting password for user:", err)
	} else {
		fmt.Println("User added and password set successfully.")
	}
}

func removeUser() {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter username to remove: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	cmd := exec.Command("sudo", "deluser", "--remove-home", username)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		// fallback for RHEL
		cmd = exec.Command("sudo", "userdel", "-r", username)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Println("Error removing user:", err)
		}
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

	// Show /etc/sudoers preview
	fmt.Println("\n--- /etc/sudoers preview ---")
	sudoersPreview, err := exec.Command("sudo", "cat", "/etc/sudoers").Output()
	if err == nil {
		lines := strings.Split(string(sudoersPreview), "\n")
		for _, line := range lines {
			if strings.Contains(line, "ALL") && !strings.HasPrefix(line, "#") {
				fmt.Println(line)
			}
		}
	} else {
		fmt.Println("(Cannot read /etc/sudoers)")
	}
	fmt.Println("----------------------------")

	// Show all groups
	groupList := getAllGroups()
	fmt.Println("\nAvailable groups:")
	for i, group := range groupList {
		fmt.Printf("%d. %s\n", i+1, group)
	}
	fmt.Print("Choose a group number: ")
	var groupIndex int
	fmt.Scan(&groupIndex)

	if groupIndex < 1 || groupIndex > len(groupList) {
		fmt.Println("Invalid group selection.")
		return
	}
	group := groupList[groupIndex-1]

	switch choice {
	case 1:
		cmd := exec.Command("sudo", "usermod", "-aG", group, username)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Println("Error adding user to group:", err)
		} else {
			fmt.Printf("User added to group '%s' successfully.\n", group)
		}
	case 2:
		cmd := exec.Command("sudo", "gpasswd", "-d", username, group)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Println("Error removing user from group:", err)
		} else {
			fmt.Printf("User removed from group '%s' successfully.\n", group)
		}
	default:
		fmt.Println("Invalid option.")
	}
}

func getAllGroups() []string {
	cmd := exec.Command("getent", "group")
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Failed to retrieve group list.")
		return []string{}
	}

	var groups []string
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		parts := strings.Split(line, ":")
		if len(parts) > 0 && parts[0] != "" {
			groups = append(groups, parts[0])
		}
	}
	return groups
}

func showUserGroups() {
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Enter username to inspect: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	cmd := exec.Command("id", username)
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("Error fetching group info for user '%s': %v\n", username, err)
		return
	}
	fmt.Printf("\nGroup info for '%s':\n%s\n", username, string(output))
}
