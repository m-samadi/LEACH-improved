function NextHop = SelectNextHop(NodeNumber,CurrentNode_ID,Neighbors_Clusterhead,Neighbors_Clusterhead_Index)

NeighborsList=zeros(NodeNumber,3); % Node_ID | RemainingEnergy | DistanceToSink
NeighborsList_Index=0;
for i=1:Neighbors_Clusterhead_Index(CurrentNode_ID,1)    
    NeighborsList_Index=NeighborsList_Index+1;

    NeighborsList(NeighborsList_Index,1)=Neighbors_Clusterhead(CurrentNode_ID,i,1);
    NeighborsList(NeighborsList_Index,2)=Neighbors_Clusterhead(CurrentNode_ID,i,2);
    NeighborsList(NeighborsList_Index,3)=Neighbors_Clusterhead(CurrentNode_ID,i,3);  
end;

% Sort NeighborsList
NeighborsList=NeighborsList(1:NeighborsList_Index,:);
NeighborsList=sortrows(NeighborsList,[2 3]);

if (NeighborsList_Index~=0)&&(NeighborsList(NeighborsList_Index,1)~=0)
    NextHop=NeighborsList(NeighborsList_Index,1);
else
    NextHop=0;
end;

end

