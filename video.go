package sillydemo

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/go-pg/pg"
)

var dbSession *pg.DB = nil

type Video struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

func getDB() *pg.DB {
	if dbSession != nil {
		return dbSession
	}
	endpoint := os.Getenv("DB_ENDPOINT")
	if len(endpoint) == 0 {
		log.Println("Environment variable `DB_ENDPOINT` is empty")
		return nil
	}
	port := os.Getenv("DB_PORT")
	if len(port) == 0 {
		log.Println("Environment variable `DB_PORT` is empty")
		return nil
	}
	user := os.Getenv("DB_USER")
	if len(user) == 0 {
		user = os.Getenv("DB_USERNAME")
		if len(user) == 0 {
			log.Println("Environment variables `DB_USER` and `DB_USERNAME` are empty")
			return nil
		}
	}
	pass := os.Getenv("DB_PASS")
	if len(pass) == 0 {
		pass = os.Getenv("DB_PASSWORD")
		if len(pass) == 0 {
			log.Println("Environment variables `DB_PASS` and `DB_PASSWORD are empty")
			return nil
		}
	}
	name := os.Getenv("DB_NAME")
	if len(name) == 0 {
		log.Println("Environment variable `DB_NAME` is empty")
		return nil
	}
	dbSession := pg.Connect(&pg.Options{
		Addr:     endpoint + ":" + port,
		User:     user,
		Password: pass,
		Database: name,
	})
	return dbSession
}

func VideosHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("Start")
	db := getDB()
	if db == nil {
		log.Println("Could not establish database connection")
		return
	}
	var videos []Video
	err := db.Model(&videos).Select()
	if err != nil {
		log.Println(err.Error())
		return
	}
	log.Println("End")
	fmt.Fprintf(w, "Videos!!!\n")
}

func VideoHandler(w http.ResponseWriter, r *http.Request) {
	id, ok := r.URL.Query()["id"]
	if !ok {
		log.Println("Query parameter `id` is missing")
		return
	}
	title, ok := r.URL.Query()["title"]
	if !ok {
		log.Println("Query parameter `title` is missing")
		return
	}
	video := &Video{
		ID:    id[0],
		Title: title[0],
	}
	db := getDB()
	if db == nil {
		return
	}
	_, err := db.Model(video).Insert()
	if err != nil {
		return
	}
}
