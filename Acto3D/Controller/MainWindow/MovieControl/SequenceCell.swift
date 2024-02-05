//
//  SequenceCell.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/07.
//

import Cocoa

protocol SequenceCellProtocol: AnyObject {
    func sequenceCellPreview(control: AnimateController.Motion)
}
protocol SequenceCellManageProtocol: AnyObject {
    func sequenceCellRemove(index : Int)
}


class SequenceCell: NSCollectionViewItem {
    
    //    @IBOutlet weak var backView: NSView!
    
    weak var seqProtocol: SequenceCellProtocol?
    weak var seqManageProtocol: SequenceCellManageProtocol?
    
    @IBOutlet weak var cellindexButton: NSButton!
    
    @IBOutlet weak var originPopup: NSPopUpButton!
    @IBOutlet weak var destPopup: NSPopUpButton!
    @IBOutlet weak var rotationPopup: NSPopUpButton!
    
    @IBOutlet weak var durationField: NSTextField!
    
    var animateController:AnimateController?
    
    var index = 0
    var workingDirPath = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 4
        
        durationField.delegate = self
        
        print("index", index, ": setSelect", isSelected.description)
        if isSelected {
            self.view.layer?.backgroundColor =  NSColor.selectedControlColor.cgColor
        } else {
            
            self.view.layer?.backgroundColor = NSColor.alternatingContentBackgroundColors[1].cgColor
        }
        print(#function)
        
        //        NotificationCenter.default.addObserver(self, selector: #selector(popupWillPop), name: NSPopUpButton.willPopUpNotification, object: nil)
    }
    
    @IBAction func indexButtonEvent(_ sender: Any) {
        seqManageProtocol?.sequenceCellRemove(index: index)
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
    
    
    @IBAction func originState(_ sender: Any) {
        self.animateController?.motionArray[index].startParamFileName = originPopup.title
    }
    @IBAction func destState(_ sender: Any) {
        self.animateController?.motionArray[index].endParamFileName = destPopup.title
    }
    @IBAction func preview(_ sender: Any) {
        self.seqProtocol?.sequenceCellPreview(control: animateController!.motionArray[index])
    }
    
    @IBAction func rotationState(_ sender: Any) {
        switch rotationPopup.indexOfSelectedItem {
        case 0:
            self.animateController?.motionArray[index].type = .fileToFile
        case 1:
            self.animateController?.motionArray[index].type = .fileToFile
        case 2:
            self.animateController?.motionArray[index].type = .fileToFile_rotate_L
        case 3:
            self.animateController?.motionArray[index].type = .fileToFile_rotate_R
        case 4:
            self.animateController?.motionArray[index].type = .fileToFile_rotate_T
        case 5:
            self.animateController?.motionArray[index].type = .fileToFile_rotate_B
        default:
            break
        }
    }
}

extension SequenceCell:NSTextFieldDelegate{
    func controlTextDidChange(_ obj: Notification) {
        self.animateController?.motionArray[index].duration = durationField.floatValue
    }
    
}
