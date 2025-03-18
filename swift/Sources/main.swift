import Foundation

// 🃏 Enum representing a card in the deck
enum Card: Codable, Equatable {
    case jokerA
    case jokerB
    case standard(String)
}

// 🎰 Pontifex Cipher Implementation
struct Pontifex {
    var deck: [Card]

    // Move a joker down by the specified number of positions
    mutating func moveJoker(_ joker: Card, positions: Int) {
        guard let idx = deck.firstIndex(of: joker) else { return }
        deck.remove(at: idx)
        deck.insert(joker, at: (idx + positions) % deck.count)
    }

    // Triple cut the deck around the jokers
    mutating func tripleCut() {
        guard let idxA = deck.firstIndex(of: .jokerA),
              let idxB = deck.firstIndex(of: .jokerB) else { return }

        let topJoker = min(idxA, idxB)
        let bottomJoker = max(idxA, idxB)

        let top = deck[0..<topJoker]
        let middle = deck[topJoker...bottomJoker]
        let bottom = deck[(bottomJoker+1)..<deck.count]

        deck = Array(bottom + middle + top)
    }

    // Perform a count cut based on the bottom card's value
    mutating func countCut() {
        let bottomCardValue = cardValue(deck.last!)
        if bottomCardValue >= deck.count { return }

        let topSlice = deck[0..<bottomCardValue]
        deck.removeSubrange(0..<bottomCardValue)
        deck.insert(contentsOf: topSlice, at: deck.count - 1)
    }

    // Generate the next keystream number
    mutating func getOutputCard() -> Int? {
        let topCardValue = cardValue(deck.first!)
        if topCardValue >= deck.count { return nil }
        let outputCard = deck[topCardValue]
        return outputCard == .jokerA || outputCard == .jokerB ? nil : cardValue(outputCard)
    }

    // Generate a keystream of the given length
    mutating func generateKeystream(count: Int) -> [Int] {
        var keystream: [Int] = []
        while keystream.count < count {
            moveJoker(.jokerA, positions: 1)
            moveJoker(.jokerB, positions: 2)
            tripleCut()
            countCut()

            if let cardValue = getOutputCard() {
                keystream.append(cardValue > 26 ? cardValue - 26 : cardValue)
            }
        }
        return keystream
    }

    // Converts a card to its numeric value
    func cardValue(_ card: Card) -> Int {
        switch card {
        case .jokerA, .jokerB:
            return 53
        case .standard(let label):
            let ranks: [String: Int] = ["A": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "J": 11, "Q": 12, "K": 13]
            return ranks[String(label.dropLast())] ?? 0
        }
    }

    // Load a deck from a JSON file
    static func loadDeck(from filePath: String) -> [String]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    // Generate a random deck and save it to a JSON file
    static func generateRandomDeck(filePath: String) {
        var cards: [String] = []
        let suits = ["C", "D", "H", "S"]
        let ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]

        for suit in suits {
            for rank in ranks {
                cards.append(rank + suit)
            }
        }
        cards.append("JOKER_A")
        cards.append("JOKER_B")
        cards.shuffle()

        let jsonData = try! JSONEncoder().encode(cards)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        try! jsonString.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)

        print("Generated random deck saved to \(filePath)")
    }
}

// 🖥️ Command-line Handling
func printHelp() {
    print("""
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
      pontifex -e "HELLO" --deck deck.json
      pontifex -d "CIPHERTEXT" --deck deck.json
      pontifex --generate new_deck.json
    """)
}

// Main Execution
var arguments = CommandLine.arguments.dropFirst()
guard !arguments.isEmpty else {
    printHelp()
    exit(0)
}

var encrypting: Bool?
var message: String?
var deckFilePath: String?

while let arg = arguments.first {
    switch arg {
    case "-e", "--encrypt":
        encrypting = true
        arguments = arguments.dropFirst()
        message = arguments.first
    case "-d", "--decrypt":
        encrypting = false
        arguments = arguments.dropFirst()
        message = arguments.first
    case "--deck":
        arguments = arguments.dropFirst()
        deckFilePath = arguments.first
    case "--generate":
        arguments = arguments.dropFirst()
        if let filePath = arguments.first {
            Pontifex.generateRandomDeck(filePath: filePath)
            exit(0)
        }
    case "-h", "--help":
        printHelp()
        exit(0)
    default:
        print("Unknown option: \(arg)")
        printHelp()
        exit(1)
    }
    arguments = arguments.dropFirst()
}

guard let mode = encrypting, let input = message, let filePath = deckFilePath, let deck = Pontifex.loadDeck(from: filePath) else {
    print("Missing required arguments!")
    printHelp()
    exit(1)
}

// Convert deck from [String] to [Card]
var cardDeck: [Card] = deck.map {
    if $0 == "JOKER_A" { return .jokerA }
    if $0 == "JOKER_B" { return .jokerB }
    return .standard($0)
}

var cipher = Pontifex(deck: cardDeck)

// Encrypt or Decrypt
if mode {
    print("Ciphertext:", cipher.generateKeystream(count: input.count).map { String($0) }.joined(separator: " "))
} else {
    print("Plaintext:", input)
}