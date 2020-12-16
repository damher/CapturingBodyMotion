/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's main view controller.
*/

import UIKit
import RealityKit
import ARKit
import Combine

class ViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var warningView: UIView!
    @IBOutlet weak var warningLabel: UILabel!
    
    // MARK: - Properties
    
    var character: BodyTrackedEntity?
    let characterAnchor = AnchorEntity()
    
    // MARK: - Lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showWarning(with: "Click on the floor")
        arView.session.delegate = self
        
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        let configuration = ARBodyTrackingConfiguration()
        configuration.planeDetection = .horizontal
        arView.session.run(configuration)
        arView.scene.addAnchor(characterAnchor)
        
        loadCharacter()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    // MARK: - Methods
    
    func loadCharacter() {
        var cancellable: AnyCancellable? = nil
        cancellable = Entity
            .loadBodyTrackedAsync(named: "character/robot.usdz")
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("Error: Unable to load model: \(error.localizedDescription)")
                    }
                    cancellable?.cancel()
                },
                receiveValue: { (character: Entity) in
                    if let character = character as? BodyTrackedEntity {
                        // Scale the character to human size
                        character.scale = [1.0, 1.0, 1.0]
                        self.character = character
                        cancellable?.cancel()
                    } else {
                        print("Error: Unable to load model as BodyTrackedEntity")
                    }
                }
            )
    }
    
    func detectFloor(_ point: CGPoint) {
        let results = arView.hitTest(point, types: [.existingPlaneUsingExtent])
        let planeAnchors = results.filter({
            guard let anchor = $0.anchor as? ARPlaneAnchor else { return false }
            switch anchor.classification {
            case .floor:
                return true
            default:
                return false
            }
        })
        
        guard let position = planeAnchors.first?.worldTransform.columns.3 else {
            showWarning(with: "Floor not found")
            return
        }
        hideWarning()
        
        // Set new character position
        characterAnchor.position = simd_make_float3(position)
        characterAnchor.position.y += character?.scale.y ?? 1 / 2
        
        // Add the character with updated transformation and position
        if let character = character, character.parent == nil {
            characterAnchor.addChild(character)
        }
    }
    
    // MARK: - UI Methods
    
    func showWarning(with text: String) {
        warningLabel.text = text
        warningView.isHidden = false
    }
    
    func hideWarning() {
        warningView.isHidden = true
    }
    
    // MARK: - Actions
    
    @IBAction func arViewTapped(_ sender: UITapGestureRecognizer) {
        detectFloor(sender.location(in: arView))
    }
}

// MARK: - ARSessionDelegate

extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            
            // Assign the human body transformation to the charachter
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
        }
    }
}
