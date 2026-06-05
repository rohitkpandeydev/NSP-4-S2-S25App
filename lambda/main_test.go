package main

import (
	"encoding/json"
	"testing"
)

func TestZenQuoteParsing(t *testing.T) {
	jsonResponse := `[{"q":"Test Quote","a":"Test Author","h":"..."}]`
	var quotes []zenQuoteResponse
	err := json.Unmarshal([]byte(jsonResponse), &quotes)
	if err != nil {
		t.Fatalf("Failed to unmarshal ZenQuote: %v", err)
	}

	if len(quotes) == 0 {
		t.Fatal("Expected at least one quote")
	}

	if quotes[0].Quote != "Test Quote" || quotes[0].Author != "Test Author" {
		t.Errorf("Unexpected quote data: %+v", quotes[0])
	}
}

func TestHuggingFaceRouterParsing(t *testing.T) {
	jsonResponse := `{
		"choices": [
			{
				"message": {
					"content": "Short sentence."
				}
			}
		]
	}`
	var routerResponse routerChatResponse
	err := json.Unmarshal([]byte(jsonResponse), &routerResponse)
	if err != nil {
		t.Fatalf("Failed to unmarshal HF Router response: %v", err)
	}

	if len(routerResponse.Choices) == 0 {
		t.Fatal("Expected at least one choice")
	}

	if routerResponse.Choices[0].Message.Content != "Short sentence." {
		t.Errorf("Unexpected content: %s", routerResponse.Choices[0].Message.Content)
	}
}
