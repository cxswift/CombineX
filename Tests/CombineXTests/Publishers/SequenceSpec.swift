import CXShim
import CXTestUtility
import CXUtility
import Foundation
import Nimble
import Quick

class SequenceSpec: QuickSpec {
    
    override func spec() {
        
        // MARK: - Send Values
        describe("Send Values") {
            typealias Sub = TracingSubscriber<Int, TestError>
            typealias Event = Sub.Event
            
            // MARK: 1.1 should send values then send finished
            it("should send values then send finished") {
                let values = Array(0..<100)
                let pub = Publishers.Sequence<[Int], TestError>(sequence: values)
                let sub = pub.subscribeTracingSubscriber(initialDemand: .unlimited)
                
                let valueEvents = values.map(Event.value)
                let expected = valueEvents + [.completion(.finished)]
                expect(sub.eventsWithoutSubscription) == expected
            }
            
            // MARK: 1.2 should send as many values as demand
            it("should send as many values as demand") {
                let values = Array(0..<100)
                
                let pub = Publishers.Sequence<[Int], TestError>(sequence: values)
                let sub = TracingSubscriber<Int, TestError>(receiveSubscription: { s in
                    s.request(.max(50))
                }, receiveValue: { v in
                    [0, 10].contains(v) ? .max(10) : .none
                }, receiveCompletion: { _ in
                })
                
                pub.subscribe(sub)
                
                let events = (0..<70).map { Event.value($0) }
                expect(sub.eventsWithoutSubscription) == events
            }
        }
        
        // MARK: - Release Resources
        describe("Release Resources") {
            
            // MARK: 2.1 subscription should release the subscriber after complete
            it("subscription should release the subscriber after complete") {
                var subscription: Subscription?
                weak var subObj: AnyObject?
                
                do {
                    let values = Array(0..<10)
                    let pub = Publishers.Sequence<[Int], Never>(sequence: values)
                    let sub = TracingSubscriber<Int, Never>(receiveSubscription: { s in
                        subscription = s
                    }, receiveValue: { _ in
                        return .none
                    }, receiveCompletion: { _ in
                    })
                    
                    subObj = sub
                    
                    pub.subscribe(sub)
                }
                
                expect(subObj).toNot(beNil())
                subscription?.request(.unlimited)
                expect(subObj).to(beNil())
                
                _ = subscription
            }
            
            // MARK: 2.2 subscription should release the subscriber after cancel
            it("subscription should release the subscriber after cancel") {
                var subscription: Subscription?
                weak var subObj: AnyObject?
                
                do {
                    let values = Array(0..<10)
                    let pub = Publishers.Sequence<[Int], Never>(sequence: values)
                    
                    let sub = TracingSubscriber<Int, Never>(receiveSubscription: { s in
                        subscription = s
                    }, receiveValue: { _ in
                        return .none
                    }, receiveCompletion: { _ in
                    })
                    
                    subObj = sub
                    
                    pub.subscribe(sub)
                }
                
                expect(subObj).toNot(beNil())
                subscription?.cancel()
                expect(subObj).to(beNil())
                
                _ = subscription
            }
        }
        
        // MARK: - Concurrent
        describe("Concurrent") {
            struct Seq: Sequence, IteratorProtocol {
                private var n = 0
                mutating func next() -> Int? {
                    defer {
                        n += 1
                    }
                    return n
                }
            }
            
            // MARK: 3.1 should send as many values as demand even if these are concurrently requested
            it("should send as many values as demand even if these are concurrently requested") {
                let g = DispatchGroup()
                let pub = Publishers.Sequence<Seq, Never>(sequence: Seq())
                
                var subscription: Subscription?
                let sub = TracingSubscriber<Int, Never>(receiveSubscription: { s in
                    subscription = s
                }, receiveValue: { _ in
                    return .none
                }, receiveCompletion: { _ in
                })
                
                pub.subscribe(sub)
                
                for _ in 0..<100 {
                    DispatchQueue.global().async(group: g) {
                        subscription?.request(.max(1))
                    }
                }
            
                g.wait()
                
                expect(sub.eventsWithoutSubscription.count) == 100
            }
            
            // MARK: 3.2 receiving value should not block cancel
            it("receiving value should not block") {
                let pub = Publishers.Sequence<Seq, Never>(sequence: Seq())
                
                var subscription: Subscription?
                let sub = TracingSubscriber<Int, Never>(receiveSubscription: { s in
                    subscription = s
                }, receiveValue: { _ in
                    Thread.sleep(forTimeInterval: 0.1)
                    return .none
                }, receiveCompletion: { _ in
                })
                
                pub.subscribe(sub)
                
                let status = LockedAtomic(0)
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                    subscription?.cancel()
                    status.store(2)
                }
                
                subscription?.request(.max(5))
                status.store(1)
                
                expect(status.load()) == 1
            }
        }
    }
}
