//usr/bin/env go run "$0" "$@"; exit "$?"

// This file is based on: https://github.com/gitpod-io/self-hosted/blob/master/utils/create-gcp-resources.go
package main

import (
	"flag"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var (
	cwd       string
	projectID string
)

func init() {
	var err error
	cwd, err = os.Getwd()
	failOnError(err)
	cwd, err = filepath.Abs(cwd)
	failOnError(err)

	flag.StringVar(&cwd, "cwd", cwd, "working directory")
}

func main() {
	flag.Parse()
	defer fmt.Println()

	fmt.Println("This is the bootstrap-environment.go script for scott-haines/gcp-k8s-rancher.")
	fmt.Println("It is re-entrant, meaning that if it fails at any point you should be able to run it again without the script failing before that point.")

	printStep("Checking the environment")
	failOnError(checkEnvironment())

	printStep("Creating gcp-k8s-rancher service account")
	failOnError(createServiceAccount())

	printStep("Initializing Terraform")
	failOnError(initializeTerraform())

	printStep("Initializing tfvars")
	failOnError(initializeTFVars())
}

func checkEnvironment() error {
	// make sure required tools are installed
	requiredTools := map[string]string{
		"gcloud":    "Google Cloud SDK is not installed - head over to https://cloud.google.com/sdk/install and install it",
		"jq":        "jq is not installed - make sure `jq` is available in the PATH",
		"terraform": "terraform is not installed - make sure `terraform` is available in the PATH",
	}
	for cmd, errmsg := range requiredTools {
		if _, err := exec.LookPath(cmd); err != nil {
			return fmt.Errorf(errmsg)
		}
	}

	// make sure we're logged in
	out, _ := run("gcloud", "auth", "list")
	if strings.Contains(out, "No credentialed accounts") {
		runLoud("gcloud", "auth", "login")
	}

	// ensure gcloud is configured properly and extract that config
	configSettings := []struct {
		V       *string
		GCPName string
		Name    string
		Link    string
	}{
		{&projectID, "core/project", "project", ""},
	}
	for _, v := range configSettings {
		out, err := run("gcloud", "config", "get-value", v.GCPName)
		if err != nil {
			return fmt.Errorf(errPrjNotConfigured)
		}

		val := strings.TrimSpace(string(out))
		if strings.Contains(val, "(unset)") {
			var desc string
			if v.Link != "" {
				desc = " (see " + v.Link + ")"
			}
			fmt.Printf("\n  \033[36mNo %s configured. \033[mPlease enter the %s%s:\n  > ", v.GCPName, v.Name, desc)
			fmt.Scanln(&val)

			val = strings.TrimSpace(val)
			if val == "" {
				return fmt.Errorf(errPrjNotConfigured)
			}

			out, err := run("gcloud", "config", "set", v.GCPName, val)
			if err != nil {
				return fmt.Errorf(out)
			}
		}

		*v.V = val
		fmt.Printf("  %s: %s\n", v.GCPName, val)
	}

	requiredServices := []string{
		"cloudresourcemanager.googleapis.com",
		"compute.googleapis.com",
		"container.googleapis.com",
		"iam.googleapis.com",
	}
	for _, s := range requiredServices {
		out, err := run("gcloud", "services", "enable", s)
		if err != nil && strings.Contains(string(out), "Billing") {
			return fmt.Errorf("billing must be enabled for this project\n  head over to https://console.cloud.google.com/billing/linkedaccount?project=" + projectID + "&folder&organizationId to set it up")
		}
		if err != nil {
			return fmt.Errorf(string(out))
		}
	}

	return nil
}

func createServiceAccount() error {
	project, _ := run("gcloud", "config", "get-value", "core/project")
	project = strings.TrimSpace(project)
	iamAccount := fmt.Sprintf("gcp-k8s-rancher@%s.iam.gserviceaccount.com", project)

	out, err := run("gcloud", "iam", "service-accounts", "create", "gcp-k8s-rancher", "--display-name", "GCP-K8S-RANCHER")
	if err != nil && strings.Contains(string(out), "Service account gcp-k8s-rancher already exists within project") {
		// Service account already exists, this is ok.
	} else if err != nil {
		return fmt.Errorf(out)
	}

	if _, err := os.Stat("secrets/gcp-k8s-rancher-key.json"); os.IsNotExist(err) {
		// create the key only if a key doesn't exist
		out, err := run("gcloud", "iam", "service-accounts", "keys", "create", "secrets/gcp-k8s-rancher-key.json", "--iam-account", iamAccount)
		if err != nil {
			os.Remove("secrets/gcp-k8s-rancher-key.json")
			return fmt.Errorf(out)
		}
	}

	policyBindings := []string{
		"roles/compute.networkAdmin",
		"roles/compute.instanceAdmin.v1",
		"roles/compute.securityAdmin",
		"roles/iam.serviceAccountAdmin",
		"roles/iam.serviceAccountKeyAdmin",
		"roles/iam.securityAdmin",
		"roles/container.admin",
	}
	serviceAccount := fmt.Sprintf("serviceAccount:%s", iamAccount)
	for _, b := range policyBindings {
		out, err := run("gcloud", "projects", "add-iam-policy-binding", project, "--member", serviceAccount, "--role", b)
		if err != nil {
			return fmt.Errorf(string(out))
		}
	}

	return nil
}

func initializeTerraform() error {
	out, err := run("terraform", "init")
	if err != nil {
		return fmt.Errorf(string(out))
	}

	return nil
}

func initializeTFVars() error {
	if _, err := os.Stat("terraform.tfvars"); err == nil {
		fmt.Printf("  \033[2mNot Required - delete terraform.tfvars\n")
		return nil
	}

	os.Remove("terraform.tfvars.temp")

	project, _ := run("gcloud", "config", "get-value", "core/project")
	project = strings.TrimSpace(project)

	f, err := os.OpenFile("terraform.tfvars.temp", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("Error opening terraform.tfvars.temp")
	}

	rancherAdm := generateRandomPassword()
	tfVars := []struct {
		Variable string
		DataType string
		Value    string
	}{
		{"PROJECT_ID", "", project},
		{"bastion_dns_use_google_dns", "[true/false]", ""},
		{"bastion_dns_username", "[string/blank]", ""},
		{"bastion_dns_password", "[string/blank]", ""},
		{"bastion_dns_fqdn", "[string/blank]", ""},
		{"rancher_web_dns_use_google_dns", "[true/false]", ""},
		{"rancher_web_dns_username", "[string/blank]", ""},
		{"rancher_web_dns_password", "[string/blank]", ""},
		{"rancher_web_dns_fqdn", "[string/blank]", ""},
		{"rancher_web_admin_password", "", rancherAdm},
	}

	var val string
	for _, t := range tfVars {
		if t.Value == "" {
			fmt.Printf("\n  \033[36mPlease provide value for %s %s.\n  > ", t.Variable, t.DataType)
			fmt.Scanln(&val)
			t.Value = val
		}

		if _, err := f.Write([]byte(fmt.Sprintf("%s = \"%s\"\n", t.Variable, t.Value))); err != nil {
			return fmt.Errorf("Error writing to terraform.tfvars.temp")
		}
	}

	fmt.Printf("  \033[2mRancher admin password: %s\n", rancherAdm)

	if err := f.Close(); err != nil {
		return fmt.Errorf("Error closing terraform.tfvars.temp")
	}

	os.Rename("terraform.tfvars.temp", "terraform.tfvars")

	return nil
}

const (
	// error printed when gcloud isn't configured properly
	errPrjNotConfigured = `GCP project unconfigured. Use 
	gcloud config set core/project <gcloud-project>
	gcloud config set compute/region <gcloud-region>
	gcloud config set compute/zone <gcloud-zone>
to set up your environment.
`
)

// printStep prints a script step in a fancy dressing
func printStep(m string) {
	fmt.Printf("\n\033[33m- %s\033[m\n", m)
}

// failOnError fails this script if an error occured
func failOnError(err error) {
	if err == nil {
		return
	}

	fmt.Fprintf(os.Stderr, "\n\n\033[31mfailure:\033[m %v\n", err)
	os.Exit(1)
}

// isAlreadyExistsErr returns true if the error was produced because a gcloud resource already exists
func isAlreadyExistsErr(err error) bool {
	return strings.Contains(strings.ToLower(err.Error()), "already exists")
}

// run executes a command end returns its output
func run(command string, args ...string) (output string, err error) {
	cmd := runC(command, args...)
	buf, err := cmd.CombinedOutput()
	if err != nil && strings.Contains(err.Error(), "exit status") {
		return string(buf), fmt.Errorf(string(buf))
	}

	return string(buf), err
}

// run executes a command and forwards the output to stdout/stderr
func runLoud(command string, args ...string) error {
	cmd := runC(command, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// runC prepares the execution of a command
func runC(command string, args ...string) *exec.Cmd {
	fmt.Printf("  \033[2mrunning: %s %s\033[m\n", command, strings.Join(args, " "))
	cmd := exec.Command(command, args...)
	cmd.Dir = cwd
	cmd.Env = os.Environ()
	return cmd
}

func generateRandomPassword() string {
	const charset = "abcdefghijklmnopqrstuvwxyz" +
		"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var password string

	rand.Seed(time.Now().UnixNano())
	for i := 0; i < 40; i++ {
		p := charset[rand.Intn(len(charset))]
		password += string(p)
	}
	return password
}
