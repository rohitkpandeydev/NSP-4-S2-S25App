package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type requestPayload struct {
	Prompt string `json:"prompt"`
}

type responsePayload struct {
	Application string `json:"application"`
	Prompt      string `json:"prompt"`
	Response    string `json:"response"`
	Source      string `json:"source"`
}

type hfRequest struct {
	Inputs string `json:"inputs"`
}

type hfResponse struct {
	GeneratedText string `json:"generated_text"`
}

type routerChatRequest struct {
	Model    string             `json:"model"`
	Messages []routerChatMessage `json:"messages"`
}

type routerChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type routerChatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

type quoteResponse struct {
	Content string `json:"content"`
	Author  string `json:"author"`
}

var httpClient = &http.Client{Timeout: 8 * time.Second}

func handler(ctx context.Context, event events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	if event.RequestContext.HTTP.Method == http.MethodOptions {
		return apiResponse(http.StatusNoContent, nil)
	}

	payload, err := parsePayload(event.Body)
	if err != nil {
		return apiResponse(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	answer, source, err := generateAnswer(ctx, payload.Prompt)
	if err != nil {
		return apiResponse(http.StatusBadGateway, map[string]string{"error": err.Error()})
	}

	return apiResponse(http.StatusOK, responsePayload{
		Application: "NSP-4-S2-S25App",
		Prompt:      payload.Prompt,
		Response:    answer,
		Source:      source,
	})
}

func parsePayload(body string) (requestPayload, error) {
	var payload requestPayload
	if strings.TrimSpace(body) == "" {
		return payload, errors.New("request body is required")
	}

	if err := json.Unmarshal([]byte(body), &payload); err != nil {
		return payload, errors.New("request body must be valid JSON")
	}

	payload.Prompt = strings.TrimSpace(payload.Prompt)
	if payload.Prompt == "" {
		return payload, errors.New("prompt is required")
	}

	return payload, nil
}

func generateAnswer(ctx context.Context, prompt string) (string, string, error) {
	token := strings.TrimSpace(os.Getenv("HUGGINGFACE_API_TOKEN"))
	if token != "" {
		answer, err := queryHuggingFaceRouter(ctx, prompt, token)
		if err == nil && strings.TrimSpace(answer) != "" {
			return answer, "huggingface", nil
		}
	}

	quote, author, err := fetchQuote(ctx)
	if err != nil {
		return fmt.Sprintf("NSP-4-S2-S25App processed: %s", prompt), "local-fallback", nil
	}

	return fmt.Sprintf("NSP-4-S2-S25App processed your prompt: %q. Public API context: %q - %s", prompt, quote, author), "quotable", nil
}

func queryHuggingFaceRouter(ctx context.Context, prompt string, token string) (string, error) {
	modelID := strings.TrimSpace(os.Getenv("HUGGINGFACE_MODEL_ID"))
	if modelID == "" {
		modelID = "mistralai/Mistral-7B-Instruct-v0.3:fastest"
	}

	body, err := json.Marshal(routerChatRequest{
		Model: modelID,
		Messages: []routerChatMessage{
			{
				Role:    "system",
				Content: "You are the backend for NSP-4-S2-S25App. Reply in one short sentence.",
			},
			{
				Role:    "user",
				Content: prompt,
			},
		},
	})
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://router.huggingface.co/v1/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", fmt.Errorf("hugging face returned HTTP %d", resp.StatusCode)
	}

	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var routerResponse routerChatResponse
	if err := json.Unmarshal(responseBody, &routerResponse); err == nil && len(routerResponse.Choices) > 0 {
		return strings.TrimSpace(routerResponse.Choices[0].Message.Content), nil
	}

	var generated []hfResponse
	if err := json.Unmarshal(responseBody, &generated); err == nil && len(generated) > 0 {
		return generated[0].GeneratedText, nil
	}

	var single hfResponse
	if err := json.Unmarshal(responseBody, &single); err == nil {
		return single.GeneratedText, nil
	}

	return "", errors.New("unexpected Hugging Face response")
}

func fetchQuote(ctx context.Context) (string, string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://api.quotable.io/random", nil)
	if err != nil {
		return "", "", err
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", "", fmt.Errorf("quote API returned HTTP %d", resp.StatusCode)
	}

	var quote quoteResponse
	if err := json.NewDecoder(resp.Body).Decode(&quote); err != nil {
		return "", "", err
	}

	return quote.Content, quote.Author, nil
}

func apiResponse(statusCode int, body interface{}) (events.APIGatewayV2HTTPResponse, error) {
	response := events.APIGatewayV2HTTPResponse{
		StatusCode: statusCode,
		Headers: map[string]string{
			"Access-Control-Allow-Origin":  "*",
			"Access-Control-Allow-Headers": "Content-Type",
			"Access-Control-Allow-Methods": "OPTIONS,POST",
			"Content-Type":                 "application/json",
		},
	}

	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			return response, err
		}
		response.Body = string(encoded)
	}

	return response, nil
}

func main() {
	lambda.Start(handler)
}
