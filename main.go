package sillydemo

import (
	"encoding/json"
	"fmt"
	"net/http"

	ofctx "github.com/OpenFunction/functions-framework-go/context"

	"github.com/OpenFunction/functions-framework-go/functions"
)

func init() {
	functions.HTTP("Root", RootHandler)
	functions.HTTP("Videos", VideosHandler, functions.WithFunctionPath("/videos"), functions.WithFunctionMethods("GET"))
	functions.HTTP("Video", VideoHandler, functions.WithFunctionPath("/video"), functions.WithFunctionMethods("POST"))
}

func RootHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"output": "This is a silly demo",
	}
	responseBytes, _ := json.Marshal(response)
	w.Header().Set("Content-type", "application/json")
	w.Write(responseBytes)
}

func HelloWorld(w http.ResponseWriter, r *http.Request) {
	vars := ofctx.VarsFromCtx(r.Context())
	fmt.Fprintf(w, "Hello, %s!\n", vars["greeting"])
}
