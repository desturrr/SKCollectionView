//
//  SKollectionView.swift
//  SKollection
//
//  Created by Suat Karakusoglu on 1/28/17.
//  Copyright © 2017 sk. All rights reserved.
//

import UIKit

open class SKCollectionView: UICollectionView
{
    public var emptyCaseInfo: SKEmptyCaseInfo?
    open var blockPullToRefresh: (() -> Void)?
    
    public var refreshControlForLowerThaniOS10: UIRefreshControl?
    
    public var collectionDatas: [SKCollectionData] = [SKCollectionData]()
    var alreadyRegisteredCells: [String] = []
    
    public var endReachedModel: SKCollectionModel?
    public var endReachedBlock: (() -> Void)?
    public var endHasNoItemLeft: Bool = false
    
    public var blockScrollViewDidScroll: (() -> Void)?

    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.initialize()
    }
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout)
    {
        super.init(frame: frame, collectionViewLayout: layout)
        self.initialize()
    }
    
    private func initialize()
    {
        self.delegate = self
        self.dataSource = self
        let layout = self.skGetLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        if #available(iOS 9.0, *) {
            layout.sectionFootersPinToVisibleBounds = true
            layout.sectionHeadersPinToVisibleBounds = true
        } else {
            debugPrint("Can not pin the header-footer views under iOS 9.")
        }
        
        self.skRegisterCellFor(identifer: "SKCollectionEmptyCaseCCell", isInsideFramework: true)
    }

    public func skSetCollectionDatas(_ collectionDatas: [SKCollectionData?])
    {
        let fullCollectionDatas = collectionDatas.flatMap{ $0 }
        self.collectionDatas = fullCollectionDatas
        
        if let emptyData = self.prepareEmptyCaseCollectionDataIfRequired(currentDatas: fullCollectionDatas)
        {
            self.collectionDatas = [emptyData]
        }
        
        self.collectionDatas.forEach { self.skRegisterCollectionData(collectionDataToRegister: $0) }
        self.reloadData()
    }
    
    private func prepareEmptyCaseCollectionDataIfRequired(currentDatas: [SKCollectionData]) -> SKCollectionData?
    {
        let isDataEmpty = currentDatas.first?.models.isEmpty ?? true
        let isEmptyCaseExists = self.emptyCaseInfo != nil
        let shouldFillEmptyCaseData = isDataEmpty && isEmptyCaseExists
        guard shouldFillEmptyCaseData else { return nil }
        
        let emptyCaseInfo = self.emptyCaseInfo!
        
        let collectionHeight = self.bounds.size.height
        let headerModelHeight = currentDatas.first?.headerModel?.viewSize().height ?? 0
        let emptyModelHeight = collectionHeight - headerModelHeight
        
        let emptyCollectionModel = SKCollectionEmptyCaseCModel(
            imageIcon: emptyCaseInfo.image,
            title: emptyCaseInfo.title,
            subTitle: emptyCaseInfo.subTitle,
            height: emptyModelHeight,
            buttonInfo: emptyCaseInfo.buttonInfo
        )
        
        emptyCollectionModel.isInsideFramework = true
        
        let emptyCollectionData = SKCollectionData(
            models: [emptyCollectionModel],
            headerModel: currentDatas.first?.headerModel,
            footerModel: currentDatas.first?.footerModel
        )
        
        return emptyCollectionData
    }

    public func skGetModelAtIndexPath(indexPath: IndexPath) -> SKCollectionModel
    {
        return self.collectionDatas[indexPath.section].models[indexPath.row]
    }
    
    public func skGetCollectionData(by id: String) -> SKCollectionData?
    {
        return self.collectionDatas.skFindFirst{ $0.dataIdentifier == id }
    }
    
    public func skScrollToModel(model: SKCollectionModel)
    {
        guard let indexPathForModelToScroll = self.skGetIndexPathOfModel(collectionModelToFindIndex: model) else { return }
        self.skScrollToItem(at: indexPathForModelToScroll)
    }

    public func skReloadModel(model: SKCollectionModel)
    {
        guard let indexPathForModel = self.skGetIndexPathOfModel(collectionModelToFindIndex: model) else { return }
        self.reloadItems(at: [indexPathForModel])
    }
    
    private func skGetIndexPathOfModel(collectionModelToFindIndex: SKCollectionModel) -> IndexPath?
    {
        var indexPath: IndexPath? = nil
        
        self.collectionDatas.enumerated().forEach { (indexSection: Int, collectionData: SKCollectionData) in
            collectionData.models.enumerated().forEach({ (indexRow:Int, collectionModel: SKCollectionModel) in
                if collectionModelToFindIndex === collectionModel {
                    indexPath = IndexPath(row: indexRow, section: indexSection)
                }
            })
        }
        return indexPath
    }
    
    public func skGetLayout() -> UICollectionViewFlowLayout
    {
        return self.collectionViewLayout as! UICollectionViewFlowLayout
    }

    private func skScrollToItem(at indexPath: IndexPath)
    {
        if self.skGetLayout().scrollDirection == .vertical {
            self.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.bottom, animated: true)
        }else {
            self.scrollToItem(at: indexPath, at: UICollectionViewScrollPosition.right, animated: true)
        }
    }
}

// MARK: Deletions
extension SKCollectionView
{
    public func removeModel(modelToRemove: SKCollectionModel)
    {
        guard let indexPathToRemove = self.skGetIndexPathOfModel(collectionModelToFindIndex: modelToRemove) else { return }
        self.collectionDatas[indexPathToRemove.section].models.remove(at: indexPathToRemove.row)
        let indexPathsToRemove = [indexPathToRemove]
        self.deleteItems(at: indexPathsToRemove)
        
        let isEmptyCaseModel = modelToRemove is SKCollectionEmptyCaseCModel
        if !isEmptyCaseModel
        {
            if let emptyData = self.prepareEmptyCaseCollectionDataIfRequired(currentDatas: self.collectionDatas)
            {
                self.collectionDatas = [emptyData]
                self.reloadData()
            }
        }
    }
}

// MARK: Insertions
extension SKCollectionView
{
    public func skInsertModel(
        at sectionDataId: String,
        modelToInsert: SKCollectionModel,
        blockSortBy: ((_ model1: SKCollectionModel, _ model2: SKCollectionModel) -> Bool),
        scrollToIt: Bool = true )
    {
        self.skRegisterCellFor(modelToRegister: modelToInsert)
        let dataSection = { () -> Int? in
            var dataSectionIndex: Int? = nil
            self.collectionDatas.enumerated().forEach { (index: Int, collectionData: SKCollectionData) in
                if sectionDataId == collectionData.dataIdentifier {
                    dataSectionIndex = index
                }
            }
            return dataSectionIndex
        }()
        
        guard let dataSectionIndex = dataSection else { return }
        
        let dataRow = { () -> Int? in
            var dataRowIndex: Int? = nil
            self.collectionDatas[dataSectionIndex].models.enumerated().forEach { (index: Int, collectionModel: SKCollectionModel) in
                let sortedResult = blockSortBy(modelToInsert, collectionModel)
                if sortedResult{
                    dataRowIndex = index
                }
            }
            return dataRowIndex
        }()
        
        let insertRowIndex = { () -> Int in
            guard let dataRowIndex = dataRow else { return 0 }
            return dataRowIndex + 1
        }()
        
        self.collectionDatas[dataSectionIndex].models.insert(modelToInsert, at: insertRowIndex)
        let indexPathToInsert = IndexPath(row: insertRowIndex, section: dataSectionIndex)
        self.insertItems(at: [indexPathToInsert])
        self.skScrollToItem(at: indexPathToInsert)
    }
    
    public func skInsertModel(model: SKCollectionModel, indexPath: IndexPath, scrollToIt: Bool = true )
    {
        self.skRegisterCellFor(modelToRegister: model)
        self.collectionDatas[indexPath.section].models.insert(model, at: indexPath.row)
        self.insertItems(at: [indexPath])
        self.skScrollToItem(at: indexPath)
    }
    
    public func skInsertCollectionData(collectionData: SKCollectionData, at index: Int?)
    {
        let indexToInsert = index ?? self.collectionDatas.count
        self.collectionDatas.insert(collectionData, at: indexToInsert)
        self.skRegisterCollectionData(collectionDataToRegister: collectionData)
        self.reloadData()
    }
    
    public func skInsertModelAtTail(model: SKCollectionModel, scrollToIt: Bool = false)
    {
        // Remove if empty case was staying
        if let emptyModel = self.collectionDatas.first?.models.first as? SKCollectionEmptyCaseCModel {
            emptyModel.removeFromCollection()
        }
        
        self.skRegisterCellFor(modelToRegister: model)
        let lastSectionIndex = self.collectionDatas.count - 1
        self.collectionDatas[lastSectionIndex].models.append(model)
        let lastIndexPath = IndexPath(row: self.collectionDatas[lastSectionIndex].models.count - 1, section: lastSectionIndex)
        self.insertItems(at: [lastIndexPath])
        if scrollToIt {
            self.skScrollToItem(at: lastIndexPath)
        }
    }
    
    public func skInsertModelsAtTail(models: [SKCollectionModel], scrollToIt: Bool = false)
    {
        models.forEach{ self.skInsertModelAtTail(model: $0, scrollToIt: scrollToIt) }
    }
}

