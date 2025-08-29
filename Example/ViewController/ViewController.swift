//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//

import UIKit
import WWHUD

// MARK: - ViewController
final class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func demo(_ sender: UIButton) {
        colorizer()
    }
}

// MARK: - 小工具
private extension ViewController {
    
    func colorizer() {
        
        guard let image = imageView.image else { return }
        
        WWHUD.shared.display()
        
        let colorizer = ImageColorizer()
        
        colorizer.colorize(image: image, completion: { result in
            
            WWHUD.shared.dismiss()
            
            switch result {
            case .success(let image): self.imageView.image = image
            case .failure(let error): print(error)
            }
        })
    }
}
