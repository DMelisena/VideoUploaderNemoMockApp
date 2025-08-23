import Foundation

class NetworkManager {
    func fetchHelloWorld(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://prime-whole-fish.ngrok-free.app/") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1, userInfo: nil)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let message = json["status"] as? String {
                    completion(.success(message))
                } else {
                    completion(.failure(NSError(domain: "Invalid JSON", code: -1, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
