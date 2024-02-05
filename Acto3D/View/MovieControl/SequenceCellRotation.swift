//
//  SequenceCellRotation.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/07.
//

import Cocoa

protocol SequenceCellRotationProtocol: AnyObject {
    func sequenceCellRotationPreview(control: AnimateController.Motion)
}
protocol SequenceCellRotationManageProtocol: AnyObject {
    func sequenceCellRemove(index : Int)
}

class SequenceCellRotation: NSCollectionViewItem {
    
    weak var delegate: SequenceCellRotationProtocol?
    weak var seqManageProtocol: SequenceCellRotationManageProtocol?
    
    @IBOutlet weak var cellindexButton: NSButton!
    
    @IBOutlet weak var rotationPopup: NSPopUpButton!
    @IBOutlet weak var originPopup: NSPopUpButton!
    
    
    @IBOutlet weak var durationField: NSTextField!
    
    var animateController:AnimateController?
    
    var index = 0
    var workingDirPath = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 4
        durationField.delegate = self
        
        print("index", index, ": setSelect", isSelected.description)
        if isSelected {
            self.view.layer?.backgroundColor =  NSColor.selectedControlColor.cgColor
        } else {
            self.view.layer?.backgroundColor = NSColor.alternatingContentBackgroundColors[1].cgColor
        }
        
    }
    
    override var isSelected: Bool{
        
        didSet{
            print("index", index, ": setSelect", isSelected.description)
            if isSelected {
                self.view.layer?.backgroundColor =  NSColor.selectedControlColor.cgColor
            } else {
                self.view.layer?.backgroundColor = NSColor.alternatingContentBackgroundColors[1].cgColor
            }
        }
    }
    @IBAction func indexButtonEvent(_ sender: Any) {
        seqManageProtocol?.sequenceCellRemove(index: index)
    }
    @IBAction func originState(_ sender: Any) {
        self.animateController?.motionArray[index].startParamFileName = originPopup.title
    }
    @IBAction func rotationState(_ sender: Any) {
        switch rotationPopup.indexOfSelectedItem {
        case 0:
            self.animateController?.motionArray[index].type = .rotate_L
        case 1:
            self.animateController?.motionArray[index].type = .rotate_R
        case 2:
            self.animateController?.motionArray[index].type = .rotate_T
        case 3:
            self.animateController?.motionArray[index].type = .rotate_B
        default:
            break
        }
    }
    
    @IBAction func preview(_ sender: Any) {
        self.delegate?.sequenceCellRotationPreview(control: animateController!.motionArray[index])
    }
    
    
}


extension SequenceCellRotation:NSTextFieldDelegate{
    func controlTextDidChange(_ obj: Notification) {
        self.animateController?.motionArray[index].duration = durationField.floatValue
    }
    
}
