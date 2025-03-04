myarray = []
mywords = []
for file_path in matched_projects:

    with open(file_path, 'r', encoding='utf-8') as file:
        input_text = file.read()
        myarray.append(len(input_text))
        mywords.append(len(encoding.encode(input_text)))
        print(f"{len(input_text)}")
        
        
np.mean(myarray)
myarray[1]
myarray[2]

542452 / 8000

67 *
