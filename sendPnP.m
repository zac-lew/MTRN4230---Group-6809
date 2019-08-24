% Array to String for GUI
function blockInfo = sendPnP(dataV)
    %Make into string '[Xi,Yi,Xf,Yf,A]'
    %32.9119  532.4741  376.4049  141.8782   43.0000
    startBracket = '[';
    endBracket = ']';
    dataV =  fix(dataV);
    stringBlock = string(dataV);    
    blockInfo = join(stringBlock,",");
    blockInfo = strcat(startBracket,blockInfo,endBracket);
end
