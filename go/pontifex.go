package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"math/rand"
	"os"
	"strings"
	"time"
)

// Card represents a playing card
type Card string

// PontifexCipher struct
type PontifexCipher struct {
	deck []Card
}

// NewPontifexCipher initializes with a deck
func NewPontifexCipher(deck []Card) *PontifexCipher {
	return &PontifexCipher{deck: deck}
}

// moveJoker moves a joker down by a given number of positions
func (p *PontifexCipher) moveJoker(joker Card, positions int) {
	idx := p.indexOf(joker)
	if idx == -1 {
		return // Prevents crash if Joker isn't found
	}
	p.remove(idx)
	newPos := (idx + positions) % len(p.deck)
	p.insert(newPos, joker)
}

// tripleCut performs a triple cut around the jokers
func (p *PontifexCipher) tripleCut() {
	idxA, idxB := p.indexOf("JOKER_A"), p.indexOf("JOKER_B")
	if idxA == -1 || idxB == -1 {
		return // Ensure jokers exist before cutting
	}
	if idxA > idxB {
		idxA, idxB = idxB, idxA
	}

	top := p.deck[:idxA]
	middle := p.deck[idxA : idxB+1]
	bottom := p.deck[idxB+1:]

	p.deck = append(bottom, append(middle, top...)...)
}

// countCut performs a count cut based on the bottom card's value
func (p *PontifexCipher) countCut() {
	bottomValue := p.cardValue(p.deck[len(p.deck)-1])
	if bottomValue >= len(p.deck) {
		return
	}

	topSlice := p.deck[:bottomValue]
	p.deck = append(p.deck[bottomValue:len(p.deck)-1], topSlice...)
	p.deck = append(p.deck, p.deck[len(p.deck)-1])
}

// getOutputCard determines the output keystream value
func (p *PontifexCipher) getOutputCard() int {
	topValue := p.cardValue(p.deck[0])
	if topValue >= len(p.deck) {
		return -1
	}

	output := p.cardValue(p.deck[topValue])
	if output == 53 { // Ignore Jokers
		return -1
	}

	if output > 26 {
		output -= 26
	}
	return output
}

// generateKeystream generates a keystream of length n
func (p *PontifexCipher) generateKeystream(n int) []int {
	stream := []int{}
	for len(stream) < n {
		p.moveJoker("JOKER_A", 1)
		p.moveJoker("JOKER_B", 2)
		p.tripleCut()
		p.countCut()

		cardValue := p.getOutputCard()
		if cardValue != -1 {
			stream = append(stream, cardValue)
		}
	}
	return stream
}

// Encrypt or Decrypt function
func (p *PontifexCipher) process(msg string, encrypt bool) string {
	msg = strings.ToUpper(msg)
	msg = strings.ReplaceAll(msg, " ", "")

	keystream := p.generateKeystream(len(msg))
	var result strings.Builder

	for i, char := range msg {
		msgVal := int(char - 'A' + 1)
		keyVal := keystream[i]

		var cipherVal int
		if encrypt {
			cipherVal = (msgVal + keyVal) % 26
		} else {
			cipherVal = (msgVal - keyVal + 26) % 26
		}

		if cipherVal == 0 {
			cipherVal = 26
		}
		result.WriteByte(byte(cipherVal - 1 + 'A'))
	}
	return result.String()
}

// Utility functions
func (p *PontifexCipher) indexOf(card Card) int {
	for i, c := range p.deck {
		if c == card {
			return i
		}
	}
	return -1
}

func (p *PontifexCipher) remove(idx int) {
	if idx < 0 || idx >= len(p.deck) {
		return // Prevents out-of-bounds error
	}
	p.deck = append(p.deck[:idx], p.deck[idx+1:]...)
}

func (p *PontifexCipher) insert(idx int, card Card) {
	if idx < 0 || idx > len(p.deck) {
		return // Prevents out-of-bounds error
	}
	p.deck = append(p.deck[:idx], append([]Card{card}, p.deck[idx:]...)...)
}

func (p *PontifexCipher) cardValue(card Card) int {
	if card == "JOKER_A" || card == "JOKER_B" {
		return 53
	}
	rankOrder := map[string]int{
		"A": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "J": 11, "Q": 12, "K": 13,
	}
	return rankOrder[string(card[:len(card)-1])]
}

// NewRandomDeck generates a random deck and saves it to a file
func NewRandomDeck(filePath string) {
	suits := []string{"C", "D", "H", "S"}
	ranks := []string{"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

	var deck []Card

	for _, suit := range suits {
		for _, rank := range ranks {
			deck = append(deck, Card(rank+suit))
		}
	}
	deck = append(deck, "JOKER_A", "JOKER_B")

	rand.Seed(time.Now().UnixNano())
	rand.Shuffle(len(deck), func(i, j int) { deck[i], deck[j] = deck[j], deck[i] })

	deckJSON, _ := json.Marshal(deck)
	_ = ioutil.WriteFile(filePath, deckJSON, 0644)

	fmt.Println("Generated random deck saved to", filePath)
}

// LoadDeck loads a deck from a JSON file
func LoadDeck(filePath string) ([]Card, error) {
	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	var deck []Card
	err = json.Unmarshal(data, &deck)
	return deck, err
}

// Command-line Handling
func printHelp() {
	fmt.Println(`
🃏 Pontifex Cipher (Solitaire)

Usage:
  pontifex -e <plaintext> --deck <deck.json>
  pontifex -d <ciphertext> --deck <deck.json>
  pontifex --generate <deck.json>   Generate a random deck

Options:
  -e, --encrypt <plaintext>   Encrypt a message
  -d, --decrypt <ciphertext>  Decrypt a message
  --deck <file.json>          JSON file containing deck order
  --generate <file.json>      Generate a random deck JSON
  -h, --help                  Show this menu

Example:
  pontifex -e "HELLO WORLD" --deck deck.json
  pontifex -d "CIPHERTEXT" --deck deck.json
  pontifex --generate new_deck.json
	`)
}

func main() {
	// Custom Help Handling
	if len(os.Args) > 1 && (os.Args[1] == "-h" || os.Args[1] == "--help") {
		printHelp()
		return
	}

	encrypt := flag.String("e", "", "Encrypt message")
	decrypt := flag.String("d", "", "Decrypt message")
	deckFile := flag.String("deck", "", "JSON file with deck order")
	generate := flag.String("generate", "", "Generate a random deck JSON file")
	flag.Parse()

	if *generate != "" {
		NewRandomDeck(*generate)
		return
	}

	if (*encrypt == "" && *decrypt == "") || *deckFile == "" {
		printHelp()
		return
	}

	deck, err := LoadDeck(*deckFile)
	if err != nil {
		fmt.Println("Failed to load deck:", err)
		os.Exit(1)
	}

	cipher := NewPontifexCipher(deck)

	if *encrypt != "" {
		fmt.Println("Ciphertext:", cipher.process(*encrypt, true))
	} else {
		fmt.Println("Plaintext:", cipher.process(*decrypt, false))
	}
}
