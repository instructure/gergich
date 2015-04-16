module Gergich
  class CoverMessages
    def self.previous_score_minus(text)
      # TODO: less brittle ... see if we can get previous score from API somehow
      text =~ /minus .(one|two)|I found some stuff that/i
    end

    def self.minus_two
      [
        "I found some stuff that needs to be fixed before merging.\nhttp://assets.diylol.com/hfs/aaf/0a0/188/resized/mr-t-time-meme-generator-get-back-to-work-fool-fc0cc7.jpg",
        "http://www.ozsticker.com/ozebayimages/620_dave_product.jpg",
        "I'm sorry Dave, I'm afraid I can't do that.",
        "I think you know what the problem is just as well as I do.",
        "This mission is too important for me to allow you to jeopardize it.",
        "Code review result:  You shall not pass!\nhttp://cdn.meme.am/instances/500x/50115948.jpg",
      ].map{ |line| "#{line} - Minus :two:" }
    end

    def self.minus_one
      [
        "I found some stuff that would be nice to fix.",
        "There's a few things that need a checkup, doctor",
        "Yeah, I'll get it into ACT.  After it fails code review 7 times\nhttp://cdn.meme.am/instances/57394274.jpg",
        "Maybe one day I'll get a code review\nhttp://cdn.meme.am/instances/51634967.jpg",
        "Suggests improvements in code review.  Puts a -1\nhttp://m.memegen.com/d6dcy7.jpg",
      ].map{ |line| "#{line} - Minus :one:" }
    end

    def self.one_comment
      [
        "Looks good, just one comment.",
        "Pretty decent overall, just one comment.",
        "Just left you one comment.  Overall not too shabby.",
        "Brace yourself for the comment I just left you\nhttp://cdn.meme.am/instances/500x/58346103.jpg",
        "Always gotta say something, amirite? :troll:",
      ]
    end

    def self.multiple_comments
      [
        "Looks good, just a few nitpicks.",
        "Pretty decent overall, just a few comments.",
        "Just left you a few comments.  Overall not too shabby.",
        "Yeah, I went ahead and didn't -2 your commit, but... I'm gonna need you to work on Saturday...\nhttp://cdn.meme.am/instances/55360576.jpg",
        "Brace yourself for the comments I just left you\nhttp://cdn.meme.am/instances/500x/58346103.jpg",
      ]
    end

    def self.now_fixed
      [
        "Much better!  You do great work :thumbsup: :smile: :thumbsup:",
        "I just ran out of gold stars, but... oh wait, here you go! :star2:\nhttp://assets.diylol.com/hfs/911/7a6/290/resized/thumbs-up-meme-generator-yay-great-job-c404db.jpg",
        "Some great work here we did.  http://cdn.meme.am/instances/500x/55107850.jpg",
        "We settled for pretty-freakin'-awesome!  http://cdn.meme.am/instances/500x/53497921.jpg",
        "Congratulations.  http://cdn.meme.am/instances/55472323.jpg",
      ]
    end
  end
end
