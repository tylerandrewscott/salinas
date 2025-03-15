#vars to use for testing 
#texts = "Test Script for Header and Long Footer\n\nAgency Name and Name of Plan\n\nThis is a test sentence to see if the\nheader removal tool can preserve sentences in the first six rows\n\nThis is an actual sentence from the actual plan\n that should not get removed.\n This is a sentence from the body of the plan.\n\nThis is a new paragraph at the end of the page but it is very short.\n Let's see if the footer remover tool can preserve it.\n\nName of Plan\n\n\nLonger Than Four Line Footer\nTest of Footer Removal for\nVery\nVery Long Footer\nPage 3"
#texts = "Test Script for Header and Short Footer\n\nAgency Name and Name of Plan\n\nThis is a test sentence to see if the\nheader removal tool can preserve sentences in the first six rows\n\nThis is an actual sentence from the actual plan\n that should not get removed.\n This is a sentence from the body of the plan.\n\nThis is a new paragraph at the end of the page but it is very short.\n Let's see if the footer remover tool can preserve it.\n\nName of Plan\n\n\nShort Footer Test\nPage 3"


#option needs to be option = "first_six_lines" or option = "matching_text"
headfootremove <- function(texts, option){
  library(stringr)
  for(pagenum in 1:length(texts)){
    #we use the first element because we are only splitting one string
    #equivalent to str_split_1
    linebreaks <- str_split(texts[pagenum],"\\n")[[1]]
    
    #HEADER
    if(option == "first_six_lines"){
      #if more than six lines of text on the page, remove everything before
      #first empty line in first six rows and possibly stuff before the 
      #second empty line
      if(length(linebreaks)>6){
        
        #search for last set of at least two \\n in a row 
        #which corresponds to a row of linebreaks that has only \\s* in it
        #before the sixth \\n 
        #which is row six in linebreaks
        #and delete it and all the rows above it (unless sentences detected in last group)
        linebreakhead <- linebreaks[1:6]
        emptylines <- which(str_detect(linebreakhead,"^\\s*$"))
        
        emptylinegroups <- sapply(c(1:length(emptylines)),
                                  function(i) {ifelse(i!=1 && (emptylines[i]==emptylines[i-1]+1),NA,emptylines[i])
                                  })
        emptylinegroups <- emptylinegroups[!is.na(emptylinegroups)]
        
        if(length(emptylinegroups)>=2){
          #consecutive empty lines are in the same "group"
          #there are multiple blocks of text in the first six lines
          
          #let's see if we can rescue sentences in the last textblock
          #grab last textblock in first six rows
          mysubset <- c(emptylinegroups[length(emptylinegroups)-1]: 
                          emptylinegroups[length(emptylinegroups)])
          mytxt <-  paste(linebreaks[mysubset], collapse = "\n") 
          #if there are a bunch of lower case words, it's probably a sentence
          if(str_count(mytxt, "\\s[a-z]") > 10){
            #keep it in the text 
            linebreaks <- linebreaks[mysubset[1]:length(linebreaks)]
          }else{
            #if it's not a sentence, remove the last textblock too
            headercut <- emptylines[length(emptylines)]
            linebreaks <- linebreaks[(headercut+1):length(linebreaks)]
          }
        }else if(length(emptylinegroups)==1){
          #if there is only one empty linegroup, delete everything before it
          headercut <- emptylines[length(emptylines)]
          linebreaks <- linebreaks[(headercut+1):length(linebreaks)]
        }
        #if there are no empty lines, don't remove anything
      }else{
        #fewer than six lines on the page
        emptylines <- which(str_detect(linebreaks,"^\\s*$"))
        if(length(emptylines)>=1){
          #just remove everything before the first set of two \\n,
          headercut <- emptylines[1]
          if(length(linebreaks)>headercut){
            linebreaks <- linebreaks[(headercut+1):length(linebreaks)]
          }else{
            #if there are no lines of text after the cut, make the text NA
            linebreaks <- NA
          }
        }else{
          # or if an empty line doesn't exist, 
          #remove everything since it's probably just a figure caption 
          #or header on a map page
          linebreaks <- NA
        }
      }
    }else if(option == "matching_text"){
      if(pagenum == 1){
        prev_page_text = ""
        prev_page_maxline = 0
      }else{
        prev_page_text = str_split(texts[pagenum-1], "\\n")[[1]]
        prev_page_maxline = length(prev_page_text)
      }
      if(pagenum == length(texts)){
        next_page_text = ""
        next_page_maxline = 0
      }else{
        next_page_text = str_split(texts[pagenum+1],"\\n")[[1]]
        next_page_maxline = length(next_page_text)
      }
      this_page_maxline = length(linebreaks)
      this_page_text = linebreaks
      #default header length = 0
      headerlines = 0
      if(next_page_maxline > 0 & this_page_maxline > 0){
        lesser_max = min(this_page_maxline, next_page_maxline)
        for(i in 1:lesser_max){
          #if this page start text matches the next page start text
          #it's a header
          if(this_page_text[1:i] == next_page_text[1:i]){
            nextheaderlines = 1:i
          }
        }
      }
      if(prev_page_maxline > 0 & this_page_maxline > 0){
        lesser_max = min(this_page_maxline, prev_page_maxline)
        for(i in 1:lesser_max){
          #if this page start text matches the prev page start text
          #it's a header
          if(this_page_text[1:i] == prev_page_text[1:i]){
            prevheaderlines = 1:i
          }
        }
      }
      #pick whichever is longer, prev or next
      if(length(prevheaderlines) > length(nextheaderlines)){
        headerlines = prevheaderlines
      }else{
        headerlines = nextheaderlines
      }
      if(sum(headerlines == 0)==0){
        linebreaks <- linebreaks[-headerlines]
      }
    }else{
      stop("option for header removal needs to be 'first_six_lines' or 'matching_text'.")
    }
    
    
    
    
    
    #FOOTER
    #and search for first set of at least two \\n in a row 
    #on or after the 3rd-from-bottom group of \\n  
    #which is where the indicator of "emptylinegroups" starting from the bottom is < 3
    #and delete everything below it
    #as long as there are four or fewer lines of text after that cut line
    #and as long as the top chunk of text on/after the 3rd-from-bottom group of \\n
    #doesn't have sentences. Otherwise, don't remove that top chunk.
    counter = 0
    emptylines <- which(str_detect(linebreaks,"^\\s*$"))
    
    if(length(emptylines)>=1){
      #consecutive empty lines are in the same "group"
      emptylinegroups <- sapply(c(1:length(emptylines)),
                                function(i) {ifelse(i!=1 && (emptylines[i]==emptylines[i-1]+1),NA,emptylines[i])
                                })
      emptylinegroups <- emptylinegroups[!is.na(emptylinegroups)]
      footercut <- ifelse(length(emptylinegroups)<3,emptylinegroups[1],
                          emptylinegroups[length(emptylinegroups)-2])
      
      if(length(emptylinegroups)>=2){
        #let's see if we can rescue sentences in the first textblock
        #grab first textblock in footer
        #which goes to the next emptyline group, if it exists,
        #or else the end of the page
        endofblock <- ifelse(any(emptylinegroups > footercut), 
                             emptylinegroups[which(emptylinegroups > footercut)[1]],
                             length(linebreaks))
        mysubset <- c(footercut: 
                        endofblock)
        mytxt <-  paste(linebreaks[mysubset], collapse = "\n") 
        #if there are a bunch of lower case words, it's probably a sentence
        if(str_count(mytxt, "\\s[a-z]") > 10){
          #keep it in the text by moving footercut to next emptyline group, if it exists, 
          #or else NA as a proxy for past the end of the page 
          footercut <- ifelse(any(emptylinegroups > footercut), 
                              emptylinegroups[which(emptylinegroups > footercut)[1]],
                              NA)
        }else{
          #leave the footer cut-off where it is, so it will be cut
        }
      }
      
      lineswithtext <- which(str_detect(linebreaks,"^\\s*$",negate = T))
      
      #counter check should be <=1, to prevent footercut from being NA
      #if footercut is already NA, that means to keep the whole page, so skip this check
      while(!is.na(footercut) & sum(lineswithtext > footercut)>4 & counter <=1){
        #the footer is too big! only allow max four footer lines
        counter = counter + 1
        #iterate one element to the right in emptylinegroups each time through the 
        #while statement
        #each loop has a stricter requirement on when to set footercut to the first group
        #and otherwise iterates one group to the right each loop
        footercut <- ifelse(length(emptylinegroups)<(3-counter),emptylinegroups[1],
                            emptylinegroups[length(emptylinegroups)-(2-counter)])
        
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
    texts[pagenum] <- str_remove(texts[pagenum],"(((p|P)age\\s)|\\s{3,})([0-9|x|v|i]{1,6}|([a-z]+\\p{Pd}[0-9]+))\\s*$")
    #remove page numbers: (word page and space or 3+ spaces) followed by (a combo of 1-6
    #roman and arabic numerals) or (a letter, hyphen, and
    #set of numbers such as c-28) at the end of a page
  }
  return(texts)
}



