package main

import (
	"bufio"
	"bytes"
	"fmt"
	"github.com/emersion/go-smtp"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/http/httputil"
	"os"
	"strings"
)

type Backend struct{}

func (bkd *Backend) Login(username, password string) (smtp.User, error) {
	return &User{}, nil
}

// Require clients to authenticate using SMTP AUTH before sending emails
func (bkd *Backend) AnonymousLogin() (smtp.User, error) {
	return &User{}, nil
}

type User struct{}

func (u *User) Send(from string, to []string, r io.Reader) (err error) {
	log.Println("Sending message:", from, to)

	b, err := ioutil.ReadAll(r)

	if err != nil {
		panic(err)
	}
	log.Println("Data:", string(b))


	scanner := bufio.NewScanner(bytes.NewReader(b))
	count := 0
	body := ""
	for scanner.Scan() {
		if count < 1 {
			if scanner.Text() == "" {
				count++
			}
			continue
		}

		l := scanner.Text()
		if strings.HasSuffix(l,"="){
			body = body + l[:len(l) - 1]
		} else {
			body = body + l + "\n"
		}
	}

	body = strings.Replace(body,"_","\\_",-1)

	log.Println("--------------")
	log.Println("Body:", string(body))
	log.Println("--------------")

	for _, t := range to {
		a := strings.Split(t, "@")
		resp, err := http.Post(fmt.Sprintf("%v/api/alert/%v", os.Getenv("HAL"),a[0]), "application/text", strings.NewReader(body))
		if err != nil {
			log.Println(err)
			continue
		}
		d, err := httputil.DumpResponse(resp, true)
		if err != nil {
			log.Println(err)
		} else {
			log.Println(string(d))
		}

		resp.Body.Close()
	}
	return nil
}

func (u *User) Logout() error {
	return nil
}

func main() {
	be := &Backend{}

	s := smtp.NewServer(be)

	s.Addr = ":1025"
	s.Domain = "localhost"
	s.MaxIdleSeconds = 300
	s.MaxMessageBytes = 1024 * 1024
	s.MaxRecipients = 50
	s.AllowInsecureAuth = true

	log.Println("Starting server at", s.Addr)
	if err := s.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
