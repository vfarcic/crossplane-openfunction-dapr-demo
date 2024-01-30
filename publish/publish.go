package publish

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

type Video struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

func EventsHandler(w http.ResponseWriter, r *http.Request) {

	errorMessage := ""

	log.Printf("I just got the video metadata, now publishing video to http://??.youtube.com/viktor!")

	status := http.StatusOK
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

func getEnv(key, fallback string) string {
	value, exists := os.LookupEnv(key)
	if !exists {
		value = fallback
	}
	return value
}
