//
//  SKCollectionViewXInsertions.swift
//  SKCollectionView
//
//  Created by Suat Karakusoglu on 12/15/17.
//  Copyright © 2017 suat.karakusoglu. All rights reserved.
//

import Foundation

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
    
    public func skInsertModel(model: SKCollectionModel, indexPath: IndexPath, scrollToIt: Bool = false)
    {
        self.skRegisterCellFor(modelToRegister: model)
        self.collectionDatas[indexPath.section].models.insert(model, at: indexPath.row)
        self.insertItems(at: [indexPath])
        
        if scrollToIt
        {
            self.skScrollToItem(at: indexPath)
        }
    }
    
    public func skInsertModel(model: SKCollectionModel, beforeModel: SKCollectionModel, scrollToIt: Bool = false)
    {
        guard let indexPathOfModel = self.skGetIndexPathOfModel(collectionModelToFindIndex: beforeModel) else { return }
        let rowToInsert = max(indexPathOfModel.row, 0)
        let indexPathToInsert = IndexPath(row: rowToInsert, section: indexPathOfModel.section)
        self.skInsertModel(model: model, indexPath: indexPathToInsert, scrollToIt: scrollToIt)
    }
    
    public func skInsertModel(model: SKCollectionModel, afterModel: SKCollectionModel, scrollToIt: Bool = false)
    {
        guard let indexPathOfModel = self.skGetIndexPathOfModel(collectionModelToFindIndex: afterModel) else { return }
        let rowToInsert = indexPathOfModel.row + 1
        let indexPathToInsert = IndexPath(row: rowToInsert, section: indexPathOfModel.section)
        self.skInsertModel(model: model, indexPath: indexPathToInsert, scrollToIt: scrollToIt)
    }
    
    public func skInsertCollectionData(collectionData: SKCollectionData, at index: Int?)
    {
        let indexToInsert = index ?? self.collectionDatas.count
        self.collectionDatas.insert(collectionData, at: indexToInsert)
        self.skRegisterCollectionData(collectionDataToRegister: collectionData)
        self.reloadData()
    }
    
    public func skInsertModelAtHead(model: SKCollectionModel, scrollToIt: Bool = false, scrollPosition: UICollectionView.ScrollPosition? = nil)
    {
        self.removeEmptyModel()

        if self.collectionDatas.isEmpty
        {
            self.collectionDatas = [SKCollectionData(models: [])]
        }
        
        self.skRegisterCellFor(modelToRegister: model)
        
        self.collectionDatas[0].models.insert(model, at: 0)
        let firstIndexPath = IndexPath(row: 0, section: 0)
        self.insertItems(at: [firstIndexPath])
        
        if scrollToIt {
            self.skScrollToItem(at: firstIndexPath, scrollPosition: scrollPosition)
        }
    }
    
    public func skInsertModelAtTail(model: SKCollectionModel, scrollToIt: Bool = false)
    {
        self.removeEmptyModel()
        self.skRegisterCellFor(modelToRegister: model)
        
        let lastSectionIndex = max(self.collectionDatas.count - 1, 0)
        self.collectionDatas[lastSectionIndex].models.append(model)
        let lastIndexPath = IndexPath(row: self.collectionDatas[lastSectionIndex].models.count - 1, section: lastSectionIndex)
        self.insertItems(at: [lastIndexPath])
        
        if scrollToIt {
            self.skScrollToItem(at: lastIndexPath)
        }
    }
    
    public func skInsertModelsAtTail(models: [SKCollectionModel])
    {
        models.forEach{ self.skInsertModelAtTail(model: $0, scrollToIt: false) }
    }
    
    public func skInsertModelsAtHead(models: [SKCollectionModel])
    {
        models.forEach{ self.skInsertModelAtHead(model: $0, scrollToIt: false) }
    }
    
    private func removeEmptyModel()
    {
        if let _ = self.collectionDatas.first?.models.first as? SKCollectionEmptyCaseCModel
        {
            self.collectionDatas[0].models.remove(at: 0)
            self.deleteItems(at: [IndexPath(row:0, section: 0)])
        }
    }
}
