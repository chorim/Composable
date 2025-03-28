## Composable

Composable is a framework for unidirectional application architecture using actor.
The basic concept of a composable is as follows;

- Easy to code-reading and to implements some business logic with less code.
- Be able to start small. You don't need to rewrite all files. Let's start with a small snippet of code.
- A lightweight framework. Easy to adopt it into your project.


### Usage
In the SwiftUI, you can create and use a Store using StateObject property wrapper.

```swift
import SwiftUI

struct CounterView: View {
    @StateObject private var store = ComposableStore<CounterFeature>(state: .init(), reducer: .init())
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Counter = \(store.state.counter)")
                .font(.largeTitle)
            
            Spacer().frame(height: 40)
            
            HStack(spacing: 8) {
                if store.state.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            await store.send(action: .increase(1))
                        }
                    } label: {
                        Text("Increase by 1")
                    }
                    
                    Button {
                        Task {
                            await store.send(action: .decrease(1))
                        }
                    } label: {
                        Text("Decrease by 1")
                    }
                }
            }
        }
    }
}
```
If the some view needs the previous Store, pass the Store using SwiftUI  `environmentObject(_:)` makes passing it so simple.

```swift
NavigationLink {
    SomeView()
        .environmentObject(store)
} label: {
    Text("Next View")
}
```

In the UIKit, you can create and use a Store and `asPublisher(_:)` for between State and UI binding.

```swift
import UIKit

final class CounterViewController: UIViewController {
    private let counterLabel: UILabel = {
        ...
    }(UILabel(frame: .zero))

    private let incrementButton: UIButton = {
        ...
    }(UIButton(type: .custom))
    
    private let decrementButton: UIButton = {
        ...
    }(UIButton(type: .custom))

    private let store = ComposableStore(
        state: CounterFeature.State(),
        reducer: CounterFeature()
    )
        
    private var subscriptions = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI() // Call to addSubview with UILabel, UIButton into the root view.
        
        bind() // To bind the state between UI
    }
    
    private func bind() {
        store.asPublisher(\.counter)
            .removeDuplicates()
            .sink(receiveValue: { [weak self] value in
                self?.counterLabel.text = "\(value)"
            })
            .store(in: &subscriptions)
    }
 
    // MARK: Actions
    @objc private func increment() {
        Task {
            await store.send(action: .increase(1))
        }
    }
    
    @objc private func decrement() {
        Task {
            await store.send(action: .decrease(1))
        }
    }
}

// MARK: UIViewControllerRepresentable
struct CounterViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        return CounterViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}
```

