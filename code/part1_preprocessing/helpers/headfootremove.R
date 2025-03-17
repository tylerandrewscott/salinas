#vars to use for testing 
#texts = "Test Script for Header and Long Footer\n\nAgency Name and Name of Plan\n\nThis is a test sentence to see if the\nheader removal tool can preserve sentences in the first six rows\n\nThis is an actual sentence from the actual plan\n that should not get removed.\n This is a sentence from the body of the plan.\n\nThis is a new paragraph at the end of the page but it is very short.\n Let's see if the footer remover tool can preserve it.\n\nName of Plan\n\n\nLonger Than Four Line Footer\nTest of Footer Removal for\nVery\nVery Long Footer\nPage 3"
#texts = "Test Script for Header and Short Footer\n\nAgency Name and Name of Plan\n\nThis is a test sentence to see if the\nheader removal tool can preserve sentences in the first six rows\n\nThis is an actual sentence from the actual plan\n that should not get removed.\n This is a sentence from the body of the plan.\n\nThis is a new paragraph at the end of the page but it is very short.\n Let's see if the footer remover tool can preserve it.\n\nName of Plan\n\n\nShort Footer Test\nPage 3"

headfootremove <- function(texts){
  library(stringr)
  for(pagenum in 1:length(texts)){
    #we use the first element because we are only splitting one string
    #equivalent to str_split_1
    linebreaks <- str_split(texts[pagenum],"\\n")[[1]]
    #HEADER
    #if more than six lines of text on the page, remove all title-case lines
    #before whichever comes first: a non-title case line, or 
    #the last empty row on or before the first six rows of the page 
    if(length(linebreaks)>6){
      #search first six rows
      linebreakhead <- linebreaks[1:6]
      #search for sets of at least two \\n in a row 
      #which correspond to a row of linebreaks that has only \\s* in it
      emptylines <- which(str_detect(linebreakhead,"^\\s*$"))
      
      emptylinegroups <- sapply(c(1:length(emptylines)),
                                function(i) {ifelse(i!=1 && (emptylines[i]==emptylines[i-1]+1),NA,emptylines[i])
                                })
      emptylinegroups <- emptylinegroups[!is.na(emptylinegroups)]
      
      #find last empty line if it exists and check everything before that for removal
      #we got rid of na's, so this outside condition makes sure the var isn't empty
      if(length(emptylinegroups) > 0){
        #this condition makes sure the last empty line isn't on line one
        if(emptylinegroups[length(emptylinegroups)] > 1){
          maxheaderlength <- emptylinegroups[length(emptylinegroups)] - 1
          #checker to see if a previous line was preserved, which means all 
          #potential header lines afterward should
          #also be preserved.
          prevlinepreserved = F
          linegetspreserved <- vector(mode = "logical", length = maxheaderlength)
          for(j in 1:maxheaderlength){
            #if there are over six lowercase words, it's probably a sentence.
            linegetspreserved[j] <- str_count(linebreaks[j], "\\s[a-z]") > 6 | 
              #alternatively, if there's at least four long lowercase words, it's probably a sentence 
              #and may have a lot of capitalized entities in it
              str_count(linebreaks[j], "\\s[a-z]{7,}") > 3
            if(linegetspreserved[j]==T){
              prevlinepreserved = T
              if(j < maxheaderlength){
                #break out of the loop and preserve later header lines if you find a 
                #sentence
                linegetspreserved[j:maxheaderlength] <- T
                break()
              }
            }
          }
          #remove the parts of the text that aren't supposed to get preserved
          if(any(linegetspreserved==F)){
            linebreaks <- linebreaks[-which(!linegetspreserved)]
          }
        }
      }else{
        #either the only empty line is on row one, or there isn't one
        #we will bias toward removing more liberally in this case
        #only search top three rows in this case
        maxheaderlength <- 3
        #checker to see if a previous line was preserved, which means all 
        #potential header lines afterward should
        #also be preserved.
        prevlinepreserved = F
        linegetspreserved <- vector(mode = "logical", length = maxheaderlength)
        for(j in 1:maxheaderlength){
          #if there are over eight lowercase words, it's probably a sentence.
          linegetspreserved[j] <- str_count(linebreaks[j], "\\s[a-z]") > 8 | 
            #alternatively, if there's at least six long lowercase words, it's probably a sentence 
            #and may have a lot of capitalized entities in it
            str_count(linebreaks[j], "\\s[a-z]{7,}") > 5
          if(linegetspreserved[j]==T){
            prevlinepreserved = T
            if(j < maxheaderlength){
              #break out of the loop and preserve later header lines if you find a 
              #sentence
              linegetspreserved[j:maxheaderlength] <- T
              break()
            }
          }
        }
        
        #remove the parts of the text that aren't supposed to get preserved
        if(any(linegetspreserved==F)){
          linebreaks <- linebreaks[-which(!linegetspreserved)]
        }
      }

    }else{
      #fewer than six lines on the page
      #let's find the empty lines
      emptylines <- which(str_detect(linebreaks,"^\\s*$"))
      
      if(length(emptylines) > 0){
        #maxheader length is the smaller of the pagelength and first emptyline location
        maxheaderlength <- min(length(linebreaks), emptylines[1])
      }else{
        maxheaderlength <- length(linebreaks)
      }
      
      #checker to see if a previous line was preserved, which means all 
      #potential header lines afterward should
      #also be preserved.
      prevlinepreserved = F
      linegetspreserved <- vector(mode = "logical", length = maxheaderlength)
      if(length(linebreaks)>0){
        for(j in 1:maxheaderlength){
          #if there are over six lowercase words, it's probably a sentence.
          linegetspreserved[j] <- str_count(linebreaks[j], "\\s[a-z]") > 6 | 
            #alternatively, if there's at least four long lowercase words, it's probably a sentence 
            #and may have a lot of capitalized entities in it
            str_count(linebreaks[j], "\\s[a-z]{7,}") > 3
          if(linegetspreserved[j]==T){
            prevlinepreserved = T
            if(j < maxheaderlength){
              #break out of the loop and preserve later header lines if you find a 
              #sentence
              linegetspreserved[j:maxheaderlength] <- T
              break()
            }
          }
        }
        #remove the parts of the text that aren't supposed to get preserved
        if(any(linegetspreserved==F)){
          linebreaks <- linebreaks[-which(!linegetspreserved)]
        }
      }else{
        #the page is empty. we will deal with this later
      }
      
    }
    #we check this again because conditions are now different from line 105
    if(length(linebreaks)==0){
      linebreaks <- NA
    }
  
    #FOOTER
    #and search for first set of at least two \\n in a row 
    #on or after the 3rd-from-bottom group of \\n  
    #which is where the indicator of "emptylinegroups" starting from the bottom is < 3
    #and delete everything below it
    #as long as there are four or fewer lines of text after that cut line
    #and as long as the top chunk of text on/after the 3rd-from-bottom group of \\n
    #doesn't have sentences. Otherwise, don't remove that top chunk.
    
    emptylines <- which(str_detect(linebreaks,"^\\s*$"))
    
    if(length(emptylines)>=1){
      #consecutive empty lines are in the same "group"
      emptylinegroups <- sapply(c(1:length(emptylines)),
                                function(i) {ifelse(i!=1 && (emptylines[i]==emptylines[i-1]+1),NA,emptylines[i])
                                })
      emptylinegroups <- emptylinegroups[!is.na(emptylinegroups)]
      #earliest emptyline group should be third from last, or
      #the first group if there are less than three
      footercut <- ifelse(length(emptylinegroups)<3,emptylinegroups[1],
                          emptylinegroups[length(emptylinegroups)-2])
      
      #if footercut is more than 6 lines from the bottom of the page, we should move it to
      #the 6th line from the bottom of the page, so stuff in the middle of the page
      #isn't eligible for being cut
      if(footercut < length(linebreaks) - 6){
        footercut <- length(linebreaks) - 6
      }
  
      #checker to see if a lower line was preserved, which means all 
      #potential footer lines upward should
      #also be preserved.
      #footer is removing more prose compared to header so we will make the prose
      #criterion looser
      lowerlinepreserved = F
      linegetspreserved <- vector(mode = "logical", length = length(linebreaks))
      #starts check at bottom and goes up
      for(j in length(linebreaks):footercut){
        #if there are over five lowercase words, it's probably a sentence.
        linegetspreserved[j] <- str_count(linebreaks[j], "\\s[a-z]") > 5 | 
          #alternatively, if there's at least three long lowercase words, it's probably a sentence 
          #and may have a lot of capitalized entities in it
          str_count(linebreaks[j], "\\s[a-z]{7,}") > 2
        if(linegetspreserved[j]==T){
          lowerlinepreserved = T
          if(j > footercut){
            #break out of the loop and preserve all earlier lines if you find a 
            #sentence
            linegetspreserved[1:j] <- T
            break()
          }
        }
      }
      #even if we didn't match, we don't want to remove any lines earlier than 
      #the original footercut
      if(footercut > 1){
        linegetspreserved[1:(footercut-1)] <- T
      }
          
      #make sure there aren't more than four lines getting removed
      #if there are, move footer cut to the next emptyline group
      
      #first, set the new footercut to be at the text that isn't supposed to get preserved
      #this either returns a line number or na if there is nothing to cut
      #but because of the second argument of max, it can't go backwards compared
      #to where it was before the for loop
      footercut <- max(which(!linegetspreserved)[1], length(linebreaks) - 6)
      
      lineswithtext <- which(str_detect(linebreaks,"^\\s*$",negate = T))
      
      counter = 0
      #counter check should be <=1, to prevent footercut from being NA
      #if footercut is already NA, that means to keep the whole page, so skip this check
      while(!is.na(footercut) & sum(lineswithtext > footercut)>4 & counter <=1){
        #the footer is too big! only allow max four footer lines
        counter = counter + 1
        #iterate one element to the right in emptylinegroups each time through the 
        #while statement
        #each loop has a stricter requirement on when to set footercut to the first group
        #and otherwise iterates one group to the right each loop
        nextgroup <- ifelse(length(emptylinegroups)<(3-counter),emptylinegroups[1],
                            emptylinegroups[length(emptylinegroups)-(2-counter)])
        #if footercut is already past that group, keep it where it is
        footercut <- max(footercut, nextgroup)
        
      }
      if(is.na(footercut) | sum(lineswithtext > footercut)>4){
        #either footercut is set to na to keep all text or
        #there are too many lines of text after the last empty row. 
        #either way, keep all text by not adjusting the var linebreaks.
      }else{
        #found the footer! cut everything after footercut
        if(footercut==1){
          #that means there's nothing useful on the page -- it's all footer
          linebreaks <- NA
        }
        linebreaks <- linebreaks[1:(footercut-1)]
      }
    }
    #else don't remove anything, since
    #there are no empty lines.
    
    texts[pagenum] <- ifelse(is.na(linebreaks[1]), NA, paste(linebreaks, collapse = "\n"))
    texts[pagenum] <- str_remove(texts[pagenum],"(((p|P)age\\s)|\\s{3,})([0-9|x|v|i]{1,6}|([A-Za-z]+\\p{Pd}[0-9]+))\\s*$")
    #remove page numbers: (word page and space or 3+ spaces) followed by (a combo of 1-6
    #roman and arabic numerals) or (a letter, hyphen, and
    #set of numbers such as c-28) at the end of a page
  }
  return(texts)
}



