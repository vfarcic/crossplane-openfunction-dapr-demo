package sillydemo

import (
	"encoding/json"
	"net/http"
	"os"

	"github.com/go-pg/pg"
)

var dbSession *pg.DB = nil

type Video struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

func getDB() (*pg.DB, string) {
	if dbSession != nil {
		return dbSession, ""
	}
	endpoint := os.Getenv("DB_ENDPOINT")
	if len(endpoint) == 0 {
		return nil, "Environment variable `DB_ENDPOINT` is empty"
	}
	port := os.Getenv("DB_PORT")
	if len(port) == 0 {
		return nil, "Environment variable `DB_PORT` is empty"
	}
	user := os.Getenv("DB_USER")
	if len(user) == 0 {
		user = os.Getenv("DB_USERNAME")
		if len(user) == 0 {
			return nil, "Environment variables `DB_USER` and `DB_USERNAME` are empty"
		}
	}
	pass := os.Getenv("DB_PASS")
	if len(pass) == 0 {
		pass = os.Getenv("DB_PASSWORD")
		if len(pass) == 0 {
			return nil, "Environment variables `DB_PASS` and `DB_PASSWORD are empty"
		}
	}
	name := os.Getenv("DB_NAME")
	if len(name) == 0 {
		return nil, "Environment variable `DB_NAME` is empty"
	}
	dbSession := pg.Connect(&pg.Options{
		Addr:     endpoint + ":" + port,
		User:     user,
		Password: pass,
		Database: name,
	})
	return dbSession, ""
}

func VideosHandler(w http.ResponseWriter, r *http.Request) {
	status := http.StatusOK
	errorMessage := ""
	var videos []Video
	db, errorMessage := getDB()
	if db == nil {
		status = http.StatusBadRequest
	} else {
		err := db.Model(&videos).Select()
		if err != nil {
			errorMessage = err.Error()
		}
	}
	w.Header().Set("Content-type", "application/json")
	w.WriteHeader(status)
	if len(errorMessage) > 0 {
		status = http.StatusBadRequest
		responseBytes, _ := json.Marshal(map[string]string{"error": errorMessage})
		w.Write(responseBytes)
	} else {
		responseBytes, _ := json.Marshal(videos)
		w.Write(responseBytes)
	}
}

func VideoHandler(w http.ResponseWriter, r *http.Request) {
	var db *pg.DB
	status := http.StatusOK
	errorMessage := ""
	id, ok := r.URL.Query()["id"]
	if !ok {
		errorMessage = "Query parameter `id` is missing"
	}
	title, ok := r.URL.Query()["title"]
	if !ok {
		errorMessage = "Query parameter `title` is missing"
	}
	if len(errorMessage) == 0 {
		video := &Video{
			ID:    id[0],
			Title: title[0],
		}
		db, errorMessage = getDB()
		if db == nil {
			errorMessage = "Could not connect to the database"
		} else {
			_, err := db.Model(video).Insert()
			if err != nil {
				errorMessage = err.Error()
			}
		}
	}
	if len(errorMessage) > 0 {
		status = http.StatusBadRequest
	}
	response := map[string]string{
		"error": errorMessage,
	}
	responseBytes, _ := json.Marshal(response)
	w.Header().Set("Content-type", "application/json")
	w.WriteHeader(status)
	w.Write(responseBytes)
}
