import UIKit
import SceneKit
import ARKit
import QRScanner

class Mostra: UIViewController, ARSCNViewDelegate {
   
    @IBOutlet weak var sceneView: ARSCNView!
    var nomeMostra: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    lazy var mapSaveURL: URL = {
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent(nomeMostra!)
        } catch {
            fatalError("Can't get file save URL: \(error.localizedDescription)")
        }
    }()
    
    var mapDataFromFile: Data? {
        return try? Data(contentsOf: mapSaveURL)
    }
    
    var worldMap: ARWorldMap?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView.delegate = self
        
        worldMap = {
            guard let data = mapDataFromFile
                else { fatalError("Map data should already be verified to exist before Load button is enabled.") }
            do {
                guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
                    else { fatalError("No ARWorldMap in archive.") }
                return worldMap
            } catch {
                fatalError("Can't unarchive ARWorldMap from file data: \(error)")
            }
        }()
        print("numero ancore mondo ricaricato: " + String(worldMap!.anchors.count))
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "marcatore", bundle: nil) else {fatalError("Missing asset")}
        configuration.detectionImages = referenceImages
        configuration.initialWorldMap = worldMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        for a in worldMap!.anchors{
            print("NOME ANCORA: " + a.name!)
            let dati = a.name?.split(separator: "%")
            if(dati![0].lowercased().contains(anchor.name!.lowercased())){
                guard let imageAnchor = anchor as? ARImageAnchor else {return}
                let referenceImage = imageAnchor.referenceImage
                var currentImage: UIImage?
                let plane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
                let planeNode = SCNNode(geometry: plane)
                let qrResponses = QRScanner.findQR(in: self.sceneView.session.currentFrame!)
                guard let urlImmagine = qrResponses.first?.feature.messageString as? String else {return}
                if let url = URL(string: urlImmagine) {
                    let task = URLSession.shared.dataTask(with: url) { data, response, error in
                        guard let data = data, error == nil else { return }
                        DispatchQueue.main.sync { /// execute on main thread
                            currentImage = UIImage(data: data)
                            guard let currentImage = currentImage else {return}
                            planeNode.scale.x = Float(dati![1])!
                            print("SCALA X: " + String(Float(dati![1])!))
                            planeNode.scale.y = Float(dati![2])!
                            print("SCALA Y: " + String(Float(dati![1])!))
                            planeNode.eulerAngles.x = -.pi/2
                            planeNode.geometry?.firstMaterial?.diffuse.contents = currentImage
                            planeNode.opacity = 1
                            node.addChildNode(planeNode)
                        }
                    }
                    task.resume()
                }
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if (!node.childNodes.isEmpty){
            let oldNode = node.childNodes.first!
            let newNode = SCNNode(geometry: oldNode.geometry)
            newNode.scale.x = oldNode.scale.x
            newNode.scale.y = oldNode.scale.y
            newNode.eulerAngles.x = -.pi/2
            newNode.geometry?.firstMaterial?.diffuse.contents = oldNode.geometry?.firstMaterial?.diffuse.contents
            newNode.opacity = 1
            node.replaceChildNode(oldNode, with: newNode)
        }
    }
}
