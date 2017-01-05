//
//  Tweet.swift
//  Twitter
//
//  Created by CS193p Instructor.
//  Copyright (c) 2015 Stanford University. All rights reserved.
//

import Foundation

// a simple container class which just holds the data in a Tweet
// IndexedKeywords are substrings of the Tweet's text
// for example, a hashtag or other user or url that is mentioned in the Tweet
// note carefully the comments on the two range properties in an IndexedKeyword
// Tweet instances re created by fetching from Twitter using a TwitterRequest

public class Tweet : CustomStringConvertible
{
    public var text: String
    public var user: User
    public var created: NSDate
    public var id: String?
    public var media = [MediaItem]()
    public var hashtags = [IndexedKeyword]()
    public var urls = [IndexedKeyword]()
    public var userMentions = [IndexedKeyword]()
    
    public struct IndexedKeyword: CustomStringConvertible
    {
        public var keyword: String              // will include # or @ or http:// prefix
        public var range: Range<String.Index>   // index into the Tweet's text property only
        public var nsrange: NSRange = NSRange()            // index into an NS[Attributed]String made from the Tweet's text
        
        public init?(data: NSDictionary?, inText: String, prefix: String?) {
            let indices = data?.value(forKeyPath: TwitterKey.Entities.Indices) as? NSArray
            if let startIndex = (indices?.firstObject as? NSNumber)?.intValue {
                if let endIndex = (indices?.lastObject as? NSNumber)?.intValue {
                    let length = inText.characters.count
                    if length > 0 {
                        let start = max(min(startIndex, length-1), 0)
                        let end = max(min(endIndex, length), 0)
                        if end > start {
                            range = inText.index(inText.startIndex, offsetBy: start)..<inText.index(inText.startIndex, offsetBy: end )  // was end - 1
                            keyword = inText.substring(with: range)
                            if prefix != nil && !keyword.hasPrefix(prefix!) && start > 0 {
                                range = inText.index(inText.startIndex, offsetBy: start - 1)..<inText.index(inText.startIndex, offsetBy: end - 2)
                                keyword = inText.substring(with: range)
                            }
                            if prefix == nil || keyword.hasPrefix(prefix!) {
                                nsrange = inText.rangeOfString(substring: keyword as NSString, nearRange: NSMakeRange(startIndex, endIndex-startIndex))
                                if nsrange.location != NSNotFound {
                                    return
                                }
                            }
                        }
                    }
                }
            }
            return nil
        }
        
        public var description: String { get { return "\(keyword) (\(nsrange.location), \(nsrange.location+nsrange.length-1))" } }
    }
    
    public var description: String { return "\(user) - \(created)\n\(text)\nhashtags: \(hashtags)\nurls: \(urls)\nuser_mentions: \(userMentions)" + (id == nil ? "" : "\nid: \(id!)") }
    
    // MARK: - Private Implementation
    
    init(text: String, user: User, created: NSDate, id: String) {
        self.text = text
        self.user = user
        self.created = created
        self.id = id
    }
    
    init?(data: NSDictionary?) {
        if let user = User(data: data?.value(forKeyPath: TwitterKey.User) as? NSDictionary) {
            self.user = user
            if let text = data?.value(forKeyPath: TwitterKey.Text) as? String {
                self.text = text
                if let created = (data?.value(forKeyPath: TwitterKey.Created) as? String)?.asTwitterDate {
                    self.created = created
                    id = data?.value(forKeyPath: TwitterKey.ID) as? String
                    if let mediaEntities = data?.value(forKeyPath: TwitterKey.Media) as? NSArray {
                        for mediaData in mediaEntities {
                            if let mediaItem = MediaItem(data: mediaData as? NSDictionary) {
                                media.append(mediaItem)
                            }
                        }
                    }
                    let hashtagMentionsArray = data?.value(forKeyPath: TwitterKey.Entities.Hashtags) as? NSArray
                    hashtags = getIndexedKeywords(dictionary: hashtagMentionsArray, inText: text, prefix: "#")
                    let urlMentionsArray = data?.value(forKeyPath: TwitterKey.Entities.URLs) as? NSArray
                    urls = getIndexedKeywords(dictionary: urlMentionsArray, inText: text, prefix: "h")
                    let userMentionsArray = data?.value(forKeyPath: TwitterKey.Entities.UserMentions) as? NSArray
                    userMentions = getIndexedKeywords(dictionary: userMentionsArray, inText: text, prefix: "@")
                    return
                }
            }
        }
        // we've failed
        // but compiler won't let us out of here with non-optional values unset
        // so set them to anything just to able to return nil
        // we could make these implicitly-unwrapped optionals, but they should never be nil, ever
        self.text = ""
        self.user = User()
        self.created = NSDate()
        return nil
    }
    
    private func getIndexedKeywords(dictionary: NSArray?, inText: String, prefix: String? = nil) -> [IndexedKeyword] {
        var results = [IndexedKeyword]()
        if let indexedKeywords = dictionary {
            for indexedKeywordData in indexedKeywords {
                if let indexedKeyword = IndexedKeyword(data: indexedKeywordData as? NSDictionary, inText: inText, prefix: prefix) {
                    results.append(indexedKeyword)
                }
            }
        }
        return results
    }
    
    struct TwitterKey {
        static let User = "user"
        static let Text = "text"
        static let Created = "created_at"
        static let ID = "id_str"
        static let Media = "entities.media"
        struct Entities {
            static let Hashtags = "entities.hashtags"
            static let URLs = "entities.urls"
            static let UserMentions = "entities.user_mentions"
            static let Indices = "indices"
        }
    }
}

private extension NSString {
    func rangeOfString(substring: NSString, nearRange: NSRange) -> NSRange {
        var start = max(min(nearRange.location, self.length-1), 0)
        var end = max(min(nearRange.location + nearRange.length, self.length), 0)
        
        var done = false
        while !done {
            let myRange = range(of: substring as String,
                                options: NSString.CompareOptions.caseInsensitive,  // was allZeros in old code
                range: NSMakeRange(start, end-start))
            if myRange.location != NSNotFound {
                return myRange
            }
            done = true
            if start > 0 { start -= 1 ; done = false }
            if end < length { end += 1 ; done = false }
        }
        return NSMakeRange(NSNotFound, 0)
    }
}

private extension String {
    var asTwitterDate: NSDate? {
        get {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
            return dateFormatter.date(from: self) as NSDate?
        }
    }
}
