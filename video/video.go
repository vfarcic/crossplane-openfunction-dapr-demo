package videos

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"

	dapr "github.com/dapr/go-sdk/client"
)

type Video struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

var (
	KEY             = "VIDEOS"
	STATESTORE_NAME = getEnv("STATESTORE_NAME", "videos-statestore")
	// PUBSUB_NAME     = getEnv("PUBSUB_NAME", "videos-pubsub")
	// PUBSUB_TOPIC    = getEnv("PUBSUB_TOPIC", "events-topic")
)

func VideosHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	errorMessage := ""
	client, err := dapr.NewClient()

	if err != nil {
		errorMessage = "1)" + err.Error()
	}

	videoStateItems, err := client.GetState(ctx, STATESTORE_NAME, KEY, nil)
	if err != nil {
		errorMessage = "2)" + err.Error()
	}

	videos := []Video{}
	if videoStateItems != nil && len(videoStateItems.Value) > 0 {
		log.Default().Printf("Values: %s ", videoStateItems.Value)
		err = json.Unmarshal(videoStateItems.Value, &videos)
		if err != nil {
			errorMessage = "3)" + err.Error()
		}
	}

	w.Header().Set("Content-type", "application/json")
	status := http.StatusOK
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

	ctx := context.Background()
	errorMessage := ""
	client, err := dapr.NewClient()

	if err != nil {
		errorMessage = err.Error()
	}

	id, ok := r.URL.Query()["id"]
	if !ok {
		errorMessage = "Query parameter `id` is missing"
	}
	title, ok := r.URL.Query()["title"]
	if !ok {
		errorMessage = "Query parameter `title` is missing"
	}

	videos := []Video{}

	videoStateItems, err := client.GetState(ctx, STATESTORE_NAME, KEY, nil)
	if err != nil {
		errorMessage = "1)" + err.Error()
	}

	if videoStateItems != nil && len(videoStateItems.Value) > 0 {
		err = json.Unmarshal(videoStateItems.Value, &videos)
		if err != nil {
			errorMessage = "2)" + err.Error()
		}
	}

	if len(errorMessage) == 0 {
		var video = Video{
			ID:    id[0],
			Title: title[0],
		}

		jsonVideo, err := json.Marshal(video)
		if err != nil {
			errorMessage = "3)" + err.Error()
		}

		videos = append(videos, video)

		jsonData, err := json.Marshal(videos)
		if err != nil {
			errorMessage = "4)" + err.Error()
		}

		if err := client.SaveState(ctx, STATESTORE_NAME, KEY, jsonData, nil); err != nil {
			errorMessage = "5)" + err.Error()
		}

		// Create a HTTP post request
		r, err := http.NewRequest("POST", "http://publish-video-function.a-team.svc.cluster.local/events", bytes.NewBuffer(jsonVideo))
		if err != nil {
			errorMessage = "6)" + err.Error()
		}

		client := &http.Client{}
		res, err := client.Do(r)
		if err != nil {
			errorMessage = "7)" + err.Error()
		}

		defer res.Body.Close()

		// // Emit Event about the stored video metadata
		// log.Printf("Json Video Event Payload: %s", jsonVideo)
		// if err := client.PublishEvent(ctx, PUBSUB_NAME, PUBSUB_TOPIC, jsonVideo); err != nil {
		// 	errorMessage = "6)" + err.Error()
		// }
	}

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
