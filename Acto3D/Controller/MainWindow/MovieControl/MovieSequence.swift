//
//  MovieSequence.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/08.
//

import Foundation
import Cocoa

class MovieSequence: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate{
    
    let pasteBoardType = NSPasteboard.PasteboardType("public.data")
    
    // parent ViewController
    weak var vc:ViewController?
    
    let view:NSCollectionView
    var logOutput:[String] = []
    
    var paramsPackage:[(String, NSImage?)] = []
    
    var animateController:AnimateController = AnimateController()
    
    init(collectionView: NSCollectionView){
        self.view = collectionView
        
        super.init()
        
        self.view.delegate = self
        self.view.dataSource = self
        
        self.view.isSelectable = true
        //        self.view.allowsMultipleSelection = true
        self.view.registerForDraggedTypes([pasteBoardType])
        
        // nibファイルの登録
        let nib = NSNib(nibNamed: "SequenceCell", bundle: nil)
        let nib2 = NSNib(nibNamed: "SequenceCellRotation", bundle: nil)
        self.view.register(nib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "sequence"))
        self.view.register(nib2, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "sequenceRotation"))
        
        self.view.reloadData()
    }
    
    func setParamPackageToItems(){
        self.view.reloadData()
    }
    
}

extension MovieSequence:SequenceCellManageProtocol, SequenceCellRotationManageProtocol{
    func sequenceCellRemove(index: Int) {
        animateController.motionArray.remove(at: index)
        self.view.reloadData()
    }
}

extension MovieSequence{
    func collectionView(_ collectionView: NSCollectionView, willDisplay item: NSCollectionViewItem, forRepresentedObjectAt indexPath: IndexPath) {
        print("display!!")
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.animateController.motionArray.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        animateController.workingDir = URL(fileURLWithPath: vc!.pathField.stringValue)
        
        print(indexPath.item)
        if (self.animateController.motionArray[indexPath.item].type == .fileToFile){
            let item = view.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "sequence"), for: indexPath) as! SequenceCell
            
            item.cellindexButton.title = indexPath.item.description
            print("seq item description", item.cellindexButton.title)
            item.index = indexPath.item
            
            item.originPopup.removeAllItems()
            item.destPopup.removeAllItems()
            
            item.animateController = animateController
            
            if(self.paramsPackage.count == 0){
                
            }else{
                let jsonFileNames = paramsPackage.map{ $0.0 }
                let jsonFileThumbnails = paramsPackage.map{ $0.1 }
                
                item.originPopup.addItems(withTitles: jsonFileNames)
                item.destPopup.addItems(withTitles: jsonFileNames)
                
                
                for (index, menuItem) in item.originPopup.itemArray.enumerated(){
                    menuItem.image = jsonFileThumbnails[index]
                }
                for (index, menuItem) in item.destPopup.itemArray.enumerated(){
                    menuItem.image = jsonFileThumbnails[index]
                }
            }
            
            item.originPopup.selectItem(withTitle: animateController.motionArray[indexPath.item].startParamFileName)
            item.destPopup.selectItem(withTitle: animateController.motionArray[indexPath.item].endParamFileName)
            item.durationField.floatValue = animateController.motionArray[indexPath.item].duration
            
            item.seqProtocol = self.vc
            item.seqManageProtocol = self
            
            return item
            
        }else{
            let item = view.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "sequenceRotation"), for: indexPath) as! SequenceCellRotation
            
            item.cellindexButton.title = indexPath.item.description
            item.index = indexPath.item
            
            item.animateController = animateController
            item.originPopup.removeAllItems()
            if(self.paramsPackage.count == 0){
                
            }else{
                let jsonFileNames = paramsPackage.map{ $0.0 }
                let jsonFileThumbnails = paramsPackage.map{ $0.1 }
                
                item.originPopup.addItems(withTitles: jsonFileNames)
                
                for (index, menuItem) in item.originPopup.itemArray.enumerated(){
                    menuItem.image = jsonFileThumbnails[index]
                }
            }
            
            item.originPopup.selectItem(withTitle: animateController.motionArray[indexPath.item].startParamFileName)
            
            switch animateController.motionArray[indexPath.item].type {
            case .rotate_L:
                item.rotationPopup.selectItem(at: 0)
            case .rotate_R:
                item.rotationPopup.selectItem(at: 1)
            case .rotate_T:
                item.rotationPopup.selectItem(at: 2)
            case .rotate_B:
                item.rotationPopup.selectItem(at: 3)
            default:
                break
            }
            item.durationField.floatValue = animateController.motionArray[indexPath.item].duration
            
            item.delegate = self.vc
            item.seqManageProtocol = self
            
            return item
        }
        
        
    }
    
    
    func collectionView(_ collectionView: NSCollectionView,
                        writeItemsAt indexPaths: Set<IndexPath>,
                        to pasteboard: NSPasteboard) -> Bool {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: indexPaths,
                                                        requiringSecureCoding: false)
            pasteboard.declareTypes([pasteBoardType], owner: self)
            pasteboard.setData(data, forType: pasteBoardType)
        } catch {
            Swift.print(error.localizedDescription)
        }
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        if proposedDropOperation.pointee == .before {
            return .move
        }
        return []
    }
    
    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        let pasteboard = draggingInfo.draggingPasteboard
        guard
            let data = pasteboard.data(forType: pasteBoardType),
            let indexPaths = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Set<IndexPath>
        else { return false }
        let newIndex = indexPath.item
        let targetIndexes = indexPaths.map({ (path) -> Int in
            return path.item
        }).sorted().reversed()
        let beforeCount = targetIndexes.filter({ (n) -> Bool in
            return n < newIndex
        }).count
        var tmpData = [AnimateController.Motion]()
        targetIndexes.forEach { (n) in
            tmpData.insert(self.animateController.motionArray.remove(at: n), at: 0)
        }
        self.animateController.motionArray.insert(contentsOf: tmpData, at: newIndex - beforeCount)
        collectionView.reloadData()
        return true
    }
}
