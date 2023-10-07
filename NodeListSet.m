function NodeList = NodeListSet(NodeList,Network_Length,Network_Width)

[m n]=size(NodeList);
for i=1:m
    NodeList(i,2)=rand(1)*Network_Length;  
    NodeList(i,3)=rand(1)*Network_Width;
end;

end

