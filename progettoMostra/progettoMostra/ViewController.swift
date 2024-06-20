import UIKit
import SceneKit
import ARKit
import QRScanner

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    @IBOutlet weak var sceneView: ARSCNView!
    var nomeRegistrazione: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handletap))
        let longtapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longtap))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        sceneView.addGestureRecognizer(longtapGestureRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "marcatore", bundle: nil) else {fatalError("Missing asset")}
        configuration.detectionImages = referenceImages
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else {return}
        var currentImage: UIImage?
        let referenceImage = imageAnchor.referenceImage
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
                    planeNode.eulerAngles.x = -.pi/2
                    planeNode.geometry?.firstMaterial?.diffuse.contents = currentImage
                    planeNode.opacity = 1
                    node.addChildNode(planeNode)
                }
            }
            task.resume()
            let virtualObjectAnchor = ARAnchor(name: url.lastPathComponent + "%" + String(planeNode.scale.x) + "%" + String(planeNode.scale.y), transform: anchor.transform)
            anchors.append(virtualObjectAnchor)
            sceneView.session.add(anchor: virtualObjectAnchor)
        }
    }

    var anchors: [ARAnchor?] = []
    
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
    
    @objc func handletap(sender: UITapGestureRecognizer){
        let tappedView = sender.view as! SCNView
        let touchlocation = sender.location(in: tappedView)
        let hitTest = tappedView.hitTest(touchlocation, options: nil)
        if !hitTest.isEmpty{
            let nodo = hitTest.first?.node
            let anchor = sceneView.anchor(for: nodo!)
            var i = 0
            for a in anchors {
                let dati = a?.name?.split(separator: "%")
                if(dati![0].lowercased().contains((anchor?.name!.lowercased())!)){
                    nodo!.scale.x += 0.2
                    nodo!.scale.y += 0.2
                    let virtualObjectAnchor = ARAnchor(name: dati![0] + "%" + String(nodo!.scale.x) + "%" + String(nodo!.scale.y), transform: anchor!.transform)
                    anchors.remove(at: i)
                    sceneView.session.remove(anchor: a!)
                    anchors.append(virtualObjectAnchor)
                    sceneView.session.add(anchor: virtualObjectAnchor)
                }
                i+=1
            }
        }
    }
    
    @objc func longtap(sender: UITapGestureRecognizer){
        let tappedView = sender.view as! SCNView
        let touchlocation = sender.location(in: tappedView)
        let hitTest = tappedView.hitTest(touchlocation, options: nil)
        if !hitTest.isEmpty{
            let nodo = hitTest.first?.node
            let anchor = sceneView.anchor(for: nodo!)
            var i = 0
            for a in anchors {
                let dati = a?.name?.split(separator: "%")
                if(dati![0].lowercased().contains((anchor?.name!.lowercased())!)){
                    nodo!.scale.x -= 0.2
                    nodo!.scale.y -= 0.2
                    let virtualObjectAnchor = ARAnchor(name: dati![0] + "%" + String(nodo!.scale.x) + "%" + String(nodo!.scale.y), transform: anchor!.transform)
                    anchors.remove(at: i)
                    sceneView.session.remove(anchor: a!)
                    anchors.append(virtualObjectAnchor)
                    sceneView.session.add(anchor: virtualObjectAnchor)
                }
                i+=1
            }
        }
    }
    
    @IBAction func salvaRegistrazione(_ sender: Any) {
        let worldMapURL: URL = {
            do {
                return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent(nomeRegistrazione!)
            } catch {
                fatalError("Error getting world map URL from document directory.")
            }
        }()
        
         sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let map = worldMap else { return }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: worldMapURL, options: [.atomic])
                print("SALVATO: " + worldMapURL.absoluteString)
            } catch {
                fatalError("Can't save map: \(error.localizedDescription)")
            }
             print("numero ancore: " + String(map.anchors.count))
             for a in map.anchors{
                 print(a.name as Any)
             }
        }
    }
}
