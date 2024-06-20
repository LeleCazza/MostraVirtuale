import UIKit

class NomeRegistrazione: UIViewController, UITextFieldDelegate{

    @IBOutlet weak var textfield: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.textfield.delegate = self
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return textfield.resignFirstResponder()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let registration = segue.destination as! ViewController
        registration.nomeRegistrazione = textfield.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
