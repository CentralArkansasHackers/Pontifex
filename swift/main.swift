import Foundation

enum Card: String, Codable {
    case jokerA = "JOKER_A", jokerB = "JOKER_B"
    case standard(String)

    var value: Int {
        switch self {
        case .jokerA, .jokerB: return 53
        case .standard(let card):
            let rank = card.dropLast()
            let ranks = ["A":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,"9":9,"10":10,"J":11,"Q":12,"K":13]
            return ranks[String(rank)] ?? 0
        }
    }
}

struct Pontifex {
    var deck: [Card]

    mutating func moveJoker(_ joker: Card, positions: Int) {
        guard let idx = deck.firstIndex(of: joker) else { return }
        deck.remove(at: idx)
        deck.insert(joker, at: (idx + positions) % deck.count)
    }

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

    mutating func countCut() {
        let bottomCardValue = deck.last!.value
        if bottomCardValue >= deck.count { return }

        let topSlice = deck[0..<bottomCardValue]
        deck.removeSubrange(0..<bottomCardValue)
        deck.insert(contentsOf: topSlice, at: deck.count - 1)
    }

    mutating func getOutputCard() -> Int? {
        let topCardValue = deck.first!.value
        if topCardValue >= deck.count { return nil }
        let outputCard = deck[topCardValue]
        return outputCard == .jokerA || outputCard == .jokerB ? nil : outputCard.value
    }

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

    func charToNumber(_ char: Character) -> Int {
        Int(char.asciiValue! - Character("A").asciiValue! + 1)
    }

    func numberToChar(_ num: Int) -> Character {
        Character(UnicodeScalar((num - 1) % 26 + Int(Character("A").asciiValue!))!)
    }

    mutating func process(message: String, encrypting: Bool) -> String {
        let cleanMessage = message.uppercased().filter { $0.isLetter }
        let keystream = generateKeystream(count: cleanMessage.count)
        var result = ""

        for (i, char) in cleanMessage.enumerated() {
            let charValue = charToNumber(char)
            let keyValue = keystream[i]
            let cipherValue = encrypting ? (charValue + keyValue) : (charValue - keyValue + 26)
            result.append(numberToChar(cipherValue % 26 == 0 ? 26 : cipherValue % 26))
        }
        return result
    }

    static func loadDeck(from filePath: String) -> [Card]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return nil }
        return try? JSONDecoder().decode([Card].self, from: data)
    }

    static func generateRandomDeck(filePath: String) {
        var cards = [Card]()
        let suits = ["C", "D", "H", "S"]
        let ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]

        for suit in suits {
            for rank in ranks {
                cards.append(.standard(rank + suit))
            }
        }
        cards += [.jokerA, .jokerB]
        cards.shuffle()

        let jsonData = try! JSONEncoder().encode(cards)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        try! jsonString.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)

        print("Generated random deck saved to \(filePath)")
    }
}

// Command-line Handling
func printHelp() {
    print("""
    Pontifex Cipher (Solitaire)
    
    Usage:
      pontifex -e <plaintext> --deck <deck.json>
      pontifex -d <ciphertext> --deck <deck.json>
      pontifex --generate <deck.json>    Generate a random deck JSON
    
    Options:
      -e, --encrypt <plaintext>   Encrypt a message
      -d, --decrypt <ciphertext>  Decrypt a message
      --deck <file.json>          JSON file with deck order
      --generate <file.json>      Generate a random deck JSON
      -h, --help                  Show this menu
    
    Example:
      pontifex -e "HELLO" --deck deck.json
      pontifex -d "IFMMP" --deck deck.json
      pontifex --generate new_deck.json
    """)
}

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

var cipher = Pontifex(deck: deck)
let output = cipher.process(message: input, encrypting: mode)

print("Result: \(output)")