//
//  ViewController.swift
//  WWDCScholars
//
//  Created by Sam Eckert on 27.02.16.
//  Copyright © 2016 WWDCScholars. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import SafariServices
import MessageUI

enum CurrentViewType {
    case List
    case Map
}

class ScholarsViewController: UIViewController, SFSafariViewControllerDelegate, MFMailComposeViewControllerDelegate, ContactButtonDelegate {
    @IBOutlet private weak var yearCollectionView: UICollectionView!
    @IBOutlet private weak var loadingView: ActivityIndicatorView!
    @IBOutlet private weak var scholarsCollectionView: UICollectionView!
    @IBOutlet private weak var extendedNavigationContainer: UIView!
    @IBOutlet private weak var mainView: UIView!
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var rightArrowImageView: UIImageView!
    @IBOutlet private weak var leftArrowImageView: UIImageView!
    @IBOutlet private weak var loginBarButtonItem: UIBarButtonItem!
    @IBOutlet private weak var mapBarButtonItem: UIBarButtonItem!
    
    private let years: [WWDC] = [.WWDC2011, .WWDC2012, .WWDC2013, .WWDC2014, .WWDC2015, .WWDC2016]
    private let locationManager = CLLocationManager()
    
    private lazy var qTree = QTree()

    private var currentYear: WWDC = .WWDC2016
    private var currentScholars: [Scholar] = []
    private var searchResults = NSArray()
    private var searchBarActive = false
    private var loggedIn = false
    private var isMapInitalized = false
    private var myLocation: CLLocationCoordinate2D?
    private var currentViewType: CurrentViewType = .List
    private var mapViewVisible = false
    private var searchText = ""
    private var searchBarBoundsY:CGFloat?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureUI()
        self.styleUI()
        
        self.currentYear = years[self.years.count - 1]
        
        ScholarsKit.sharedInstance.loadScholars({
            if self.loadingView.isAnimating() {
                self.loadingView.stopAnimating()
            }
            
            self.getCurrentScholars()
        })
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == String(ScholarDetailViewController) {
            if let indexPath = sender as? NSIndexPath {
                let destinationViewController = segue.destinationViewController as! ScholarDetailViewController
                destinationViewController.currentScholar = self.searchBarActive ? self.searchResults[indexPath.item] as! Scholar : self.currentScholars[indexPath.item]
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.loadingView.isAnimating() {
            self.loadingView.stopAnimating()
        }
        
        self.getCurrentScholars()
        
        let index = self.years.indexOf(self.currentYear)!
        self.yearCollectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: index, inSection: 0), atScrollPosition: .Left, animated: false)
        self.updateArrowsForIndex(index)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if !searchBarActive {
            self.scholarsCollectionView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)
            self.scholarsCollectionView.setContentOffset(CGPointZero, animated: true)
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
//        cancelSearching()
    }
    
    // MARK: - UI
    
    private func configureUI() {
        self.searchBarBoundsY = (self.navigationController?.navigationBar.frame.size.height)! + UIApplication.sharedApplication().statusBarFrame.size.height
//        addObservers()

        let longPressGestureRecognizerLoginBarButtomItem = UILongPressGestureRecognizer(target: self, action: #selector(ScholarsViewController.showEditDetailsModal(_:)))
        self.view.addGestureRecognizer(longPressGestureRecognizerLoginBarButtomItem)
     
        self.loadingView.startAnimating()
        
        if self.traitCollection.forceTouchCapability == .Available {
            self.registerForPreviewingWithDelegate(self, sourceView: self.view)
        }
    }
    
    private func styleUI() {
        self.title = "Scholars"
        
        self.searchBar.tintColor = UIColor.scholarsPurpleColor()
        self.extendedNavigationContainer.applyExtendedNavigationBarContainerStyle()
        self.applyExtendedNavigationBarStyle()
        self.leftArrowImageView.tintColor = UIColor.transparentWhiteColor()
        self.rightArrowImageView.tintColor = UIColor.transparentWhiteColor()
    }
    
    private func configureMap() {
        // Map related
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.requestWhenInUseAuthorization()
        } else {
            self.myLocation = self.mapView.userLocation.coordinate as CLLocationCoordinate2D
        }
        
        let zoomRegion = MKCoordinateRegionMakeWithDistance(self.mapView.centerCoordinate, 10000000.0, 10000000.0)
        self.mapView.setRegion(zoomRegion, animated: true)
        self.mapView.showsUserLocation = true
        self.mapView.delegate = self
        self.mapView.mapType = .Standard
        
        //The "Find me" button
        let locateButton = UIButton(type: .Custom)
        locateButton.frame = CGRect(x: UIScreen.mainScreen().bounds.width - 41, y: 8, width: 33, height: 33)
        locateButton.setImage(UIImage(named: "locationButton"), forState: .Normal)
        locateButton.addTarget(self, action: #selector(ScholarsViewController.locateButtonAction), forControlEvents: .TouchUpInside)
        locateButton.layer.shadowOpacity = 0.5
        locateButton.layer.shadowOffset = CGSizeMake(0.0, 0.0)
        locateButton.layer.shadowRadius = 2.0
        locateButton.layer.cornerRadius = locateButton.frame.width / 2.0
        locateButton.layer.masksToBounds = true
        locateButton.backgroundColor = UIColor.scholarsPurpleColor()
        
        self.mapView.addSubview(locateButton)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    // MARK: - IBActions
    
    @IBAction func accountButtonTapped(sender: AnyObject) {
        self.loggedIn ? self.showEditDetailsModal() : self.showSignInModal()
    }
    
    @IBAction func mapButtonTapped(sender: AnyObject) {
        
        switch mapViewVisible {
        case false:
            self.mapBarButtonItem.image = UIImage(named: "gridIcon")
            mapViewVisible = true
            break
        case true:
            self.mapBarButtonItem.image = UIImage(named: "mapIcon")
            mapViewVisible = false
            break
        }
        
        if !self.isMapInitalized {
            self.configureMap()
            self.isMapInitalized = true
        }
        
        self.switchView()
    }
    
    // MARK: - Private functions
    
    private func cancelSearching(setOffset: Bool = false) {
        self.searchBarActive = false
        self.searchBar!.resignFirstResponder()
        self.searchBar!.text = ""
        self.scholarsCollectionView.reloadData()
        if setOffset {
            self.scholarsCollectionView.setContentOffset(CGPointZero, animated: true)
        }
    }
    
    private func filterContentForSearchText() {
        let resultPredicate = NSPredicate(format: "fullName contains[cd] %@", self.searchText)
        self.searchResults = (self.currentScholars as NSArray).filteredArrayUsingPredicate(resultPredicate)
        
        self.scholarsCollectionView.reloadData()
    }
    
    private func switchView() {
        UIView.animateWithDuration(0.2, animations: {
            self.mainView.alpha = self.currentViewType == .List ? 0.0 : 1.0
            self.mapView.alpha = self.currentViewType == .Map ? 0.0 : 1.0
        })
        
        self.currentViewType = self.currentViewType == .List ? .Map : .List
        
        self.cancelSearching()
    }
    
    private func getCurrentScholars() {
        self.currentScholars = DatabaseManager.sharedInstance.scholarsForWWDCBatch(self.currentYear)
        
        if self.searchBarActive {
            self.filterContentForSearchText()
        } else {
            self.scholarsCollectionView.reloadData()
        }
        
        self.addScholarToQTree()
    }
    
    private func addScholarToQTree() {
        self.qTree.cleanup()
        
        for scholar in self.currentScholars {
            let location = scholar.location
            let annotation = ScholarAnnotation(coordinate: CLLocationCoordinate2DMake(location.latitude, location.longitude), title: scholar.fullName, subtitle: location.name)
            self.qTree.insertObject(annotation)
        }
        
        self.reloadAnnotations()
    }

    private func scrollCollectionViewToIndexPath(index: Int) {
        self.yearCollectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: index, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.Left, animated: false)
        self.scrollViewDidEndDecelerating(self.yearCollectionView)
    }
    
    private func showSignInModal() {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let modalViewController = storyboard.instantiateViewControllerWithIdentifier("SignInVC")
        
        modalViewController.modalPresentationStyle = .OverCurrentContext
        modalViewController.modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
        self.view.window?.rootViewController?.view.window?.rootViewController!.presentViewController(modalViewController, animated: true, completion: nil)
    }
    
    private func showEditDetailsModal() {
        
    }
    
    // MARK: - Internal functions
    
    internal func openContactURL(url: String) {
        let viewController = SFSafariViewController(URL: NSURL(string: url)!)
        viewController.delegate = self
        
        self.presentViewController(viewController, animated: true, completion: nil)
    }
    
    internal func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    internal func composeEmail(address: String) {
        if MFMailComposeViewController.canSendMail() {
            let viewController = MFMailComposeViewController()
            viewController.mailComposeDelegate = self
            viewController.setToRecipients([address])
            
            presentViewController(viewController, animated: true, completion: nil)
        }
    }
    
    internal func safariViewControllerDidFinish(controller: SFSafariViewController) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    internal func showEditDetailsModal(longPressGestureRecognizerLoginBarButtomItem: UIGestureRecognizer) {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let modalViewController = storyboard.instantiateViewControllerWithIdentifier("EditDetailsNC")
        
        modalViewController.modalPresentationStyle = .FullScreen
        modalViewController.modalTransitionStyle = .CoverVertical
        self.presentViewController(modalViewController, animated: true, completion: nil)
    }
    
    internal func locateButtonAction(sender: UIButton!) {
        let myLocation = self.mapView.userLocation.coordinate as CLLocationCoordinate2D
        let zoomRegion = MKCoordinateRegionMakeWithDistance(myLocation, 5000000, 5000000)
        self.mapView.setRegion(zoomRegion, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension ScholarsViewController: UISearchBarDelegate {
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        
        if searchText.characters.count > 0 {
            self.searchBarActive = true
            self.filterContentForSearchText()
        } else {
            self.searchBarActive = false
            self.scholarsCollectionView.reloadData()
        }
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        self.cancelSearching(true)
    }
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        self.searchBar!.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
//        self.searchBarActive = false
        self.searchBar!.setShowsCancelButton(false, animated: false)
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        self.searchBarActive = true
        self.view.endEditing(true)
    }
}

// MARK: - UIScrollViewDelegate

extension ScholarsViewController: UIScrollViewDelegate {
    internal func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if scrollView == self.yearCollectionView {
            //scholarsCollectionView page changed, update scholars list
            
            let currentIndex = Int(self.yearCollectionView.contentOffset.x / self.view.frame.size.width)
            self.currentYear = self.years[currentIndex]
            
            self.getCurrentScholars()
            self.scholarsCollectionView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0)
            self.scholarsCollectionView.setContentOffset(CGPointZero, animated: true)
            self.updateArrowsForIndex(currentIndex)
        }
    }
    
    private func updateArrowsForIndex(currentIndex: Int) {
        UIView.animateWithDuration(0.2, animations: {
            self.leftArrowImageView.alpha = currentIndex == 0 ? 0.0 : 1.0
            self.rightArrowImageView.alpha = currentIndex == self.years.count - 1 ? 0.0 : 1.0
        })
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView == self.yearCollectionView {
            UIView.animateWithDuration(0.2, animations: {
                self.leftArrowImageView.alpha = 0.0
                self.rightArrowImageView.alpha = 0.0
            })
        } else if scrollView == self.scholarsCollectionView {
            self.searchBar.frame.origin.y = -scrollView.contentOffset.y - 44.0
        }
    }
}

// MARK: - UICollectionViewDataSource

extension ScholarsViewController: UICollectionViewDataSource {
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.scholarsCollectionView {
            return self.searchBarActive ? self.searchResults.count : self.currentScholars.count
        } else if collectionView == self.yearCollectionView {
            return self.years.count
        }
        
        return 0
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        if collectionView == self.scholarsCollectionView {
            let cell = self.scholarsCollectionView.dequeueReusableCellWithReuseIdentifier("scholarCollectionViewCell", forIndexPath: indexPath) as! ScholarCollectionViewCell
            let scholar = self.searchBarActive ? self.searchResults[indexPath.item] as! Scholar : self.currentScholars[indexPath.item]
            
            cell.nameLabel.text = scholar.firstName
            if scholar.profilePicURL != "" {
                cell.profileImageView.af_setImageWithURL(NSURL(string: scholar.profilePicURL)!, placeholderImage: UIImage(named: "placeholder"), imageTransition: .CrossDissolve(0.2), runImageTransitionIfCached: false)
            }
            
            return cell
        } else if collectionView == self.yearCollectionView {
            let cell = self.yearCollectionView.dequeueReusableCellWithReuseIdentifier("yearCollectionViewCell", forIndexPath: indexPath) as! YearCollectionViewCell
            
            cell.yearLabel.text = self.years[indexPath.item].rawValue
            
            return cell
        }
        
        return UICollectionViewCell()
    }
}

// MARK: - UICollectionViewDelegate

extension ScholarsViewController: UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        if collectionView == self.scholarsCollectionView {
            return CGSize(width: (self.scholarsCollectionView.frame.size.width / 3.0) - 8.0, height: 140.0)
        } else if collectionView == self.yearCollectionView {
            return CGSize(width: self.view.bounds.width, height: 50.0)
        }
        
        return CGSize.zero
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if collectionView == self.scholarsCollectionView {
            self.view.endEditing(true)
            
            self.performSegueWithIdentifier(String(ScholarDetailViewController), sender: indexPath)
        } else if collectionView == self.yearCollectionView {
            print(indexPath.row)
        }
    }
}

// MARK: - UIViewControllerPreviewingDelegate

extension ScholarsViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let viewController = storyboard?.instantiateViewControllerWithIdentifier("scholarDetailViewController") as? ScholarDetailViewController
        let cellPosition = self.scholarsCollectionView.convertPoint(location, fromView: self.view)
        let cellIndex = self.scholarsCollectionView.indexPathForItemAtPoint(cellPosition)
        
        guard let previewViewController = viewController, indexPath = cellIndex, cell = self.scholarsCollectionView.cellForItemAtIndexPath(indexPath) else {
            return nil
        }
        
        let scholar = self.searchBarActive ? self.searchResults[indexPath.item] as! Scholar : self.currentScholars[indexPath.item]
        previewViewController.currentScholar = scholar
        previewViewController.delegate = self
        previewViewController.preferredContentSize = CGSize.zero
        previewingContext.sourceRect = self.view.convertRect(cell.frame, fromView: self.scholarsCollectionView)
        
        return previewViewController
    }
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController) {
        self.view.endEditing(true)
        
        self.showViewController(viewControllerToCommit, sender: self)
    }
}

// MARK: - MKMapViewDelegate

extension ScholarsViewController: MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.isKindOfClass(QCluster.classForCoder()) {
            var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(ClusterAnnotationView.reuseId()) as? ClusterAnnotationView
            
            if annotationView == nil {
                annotationView = ClusterAnnotationView(cluster: annotation)
            }
            
            annotationView!.cluster = annotation
            
            return annotationView
        } else if annotation.isKindOfClass(ScholarAnnotation.classForCoder()) {
            var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier("ScholarAnnotation")
            
            if pinView == nil {
                pinView = MKAnnotationView(annotation: annotation, reuseIdentifier: "ScholarAnnotation")
                pinView?.canShowCallout = true
                pinView?.rightCalloutAccessoryView = UIButton(type: UIButtonType.DetailDisclosure)
                pinView?.rightCalloutAccessoryView!.tintColor = UIColor.blackColor()
            } else {
                pinView?.annotation = annotation
            }
            
            pinView?.image = UIImage(named: "scholarMapAnnotation")
            
            return pinView
        }
        
        return nil
    }
    
    func reloadAnnotations() {
        guard self.isViewLoaded() else {
            return
        }
        
        let mapRegion = self.mapView.region
        let minNonClusteredSpan = min(mapRegion.span.latitudeDelta, mapRegion.span.longitudeDelta) / 5
        let objects = self.qTree.getObjectsInRegion(mapRegion, minNonClusteredSpan: minNonClusteredSpan) as NSArray
        for object in objects {
            if object.isKindOfClass(QCluster) {
                let c = object as? QCluster
                let neighbours = self.qTree.neighboursForLocation((c?.coordinate)!, limitCount: NSInteger((c?.objectsCount)!)) as NSArray
                for neighbour in neighbours {
                    let _ = self.currentScholars.filter({
                        return $0.fullName == (neighbour.title)!
                    })
                }
            } else {
                let _ = self.currentScholars.filter({
                    return $0.fullName == (object.title)!
                })
            }
        }
        
        let annotationsToRemove = (self.mapView.annotations as NSArray).mutableCopy() as! NSMutableArray
        annotationsToRemove.removeObject(self.mapView.userLocation)
        annotationsToRemove.removeObjectsInArray(objects as [AnyObject])
        self.mapView.removeAnnotations(annotationsToRemove as [AnyObject] as! [MKAnnotation])
        let annotationsToAdd = objects.mutableCopy() as! NSMutableArray
        annotationsToAdd.removeObjectsInArray(self.mapView.annotations)
        
        self.mapView.addAnnotations(annotationsToAdd as [AnyObject] as! [MKAnnotation])
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        self.reloadAnnotations()
    }
}
