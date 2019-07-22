import Quick
import Nimble

#if USE_COMBINE
import Combine
#elseif SWIFT_PACKAGE
import CombineX
#else
import Specs
#endif

class ZipSpec: QuickSpec {
    
    override func spec() {
        
        // MARK: - Relay
        describe("Relay") {
        
            // MARK: 1.1 should zip of 2
            it("should zip of 2") {
                let subject0 = PassthroughSubject<String, CustomError>()
                let subject1 = PassthroughSubject<String, CustomError>()
                
                let pub = subject0.zip(subject1, +)
                let sub = makeCustomSubscriber(String.self, CustomError.self, .unlimited)
                pub.subscribe(sub)
                
                subject0.send("0")
                subject0.send("1")
                subject1.send("a")
                
                subject0.send("2")
                subject1.send("b")
                subject1.send("c")
                
                let expected = ["0a", "1b", "2c"].map { CustomEvent<String, CustomError>.value($0) }
                expect(sub.events).to(equal(expected))
            }
            
            // MARK: 1.2 should combine latest of 3
            it("should combine latest of 3") {
                let subject0 = PassthroughSubject<String, CustomError>()
                let subject1 = PassthroughSubject<String, CustomError>()
                let subject2 = PassthroughSubject<String, CustomError>()
                
                let pub = subject0.zip(subject1, subject2, { $0 + $1 + $2 })
                let sub = makeCustomSubscriber(String.self, CustomError.self, .unlimited)
                pub.subscribe(sub)
                
                subject0.send("0")
                subject0.send("1")
                subject0.send("2")
                subject1.send("a")
                subject1.send("b")
                subject2.send("A")

                subject0.send("3")
                subject1.send("c")
                subject1.send("d")
                subject2.send("B")
                subject2.send("C")
                subject2.send("D")
                
                let expected = ["0aA", "1bB", "2cC", "3dD"].map { CustomEvent<String, CustomError>.value($0) }
                expect(sub.events).to(equal(expected))
            }
            
            // MARK: 1.3 should send as many as demands
            it("should send as many as demands") {
                let subject0 = CustomSubject<String, CustomError>()
                let subject1 = CustomSubject<String, CustomError>()
                
                var counter = 0
                let pub = subject0.zip(subject1, +)
                let sub = CustomSubscriber<String, CustomError>(receiveSubscription: { (s) in
                    s.request(.max(10))
                }, receiveValue: { v in
                    defer { counter += 1}
                    return [0, 10].contains(counter) ? .max(1) : .none
                }, receiveCompletion: { c in
                })
                pub.subscribe(sub)
                
                100.times {
                    [subject0, subject1].randomElement()!.send("\($0)")
                }
                
                expect(sub.events.count).to(equal(12))
            }
        }
    }
}
