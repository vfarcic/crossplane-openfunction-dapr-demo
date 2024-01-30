package publish

import (
	"encoding/json"
	"net/http"

	"github.com/OpenFunction/functions-framework-go/functions"
)

func init() {
	functions.HTTP("Root", RootHandler)
	functions.HTTP("Events", EventsHandler, functions.WithFunctionPath("/events"), functions.WithFunctionMethods("POST"))
}

func RootHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"output": "This is the publish video function",
	}
	responseBytes, _ := json.Marshal(response)
	w.Header().Set("Content-type", "application/json")
	w.Write(responseBytes)
}
