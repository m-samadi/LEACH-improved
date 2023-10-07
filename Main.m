% LEACH-Improved protocol
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%





%%%%% Variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
InitialNodeEnergy=1;
InitialTemperatureValue=30;
RWP_Point_Count=100;
RWP_Point=zeros(RWP_Point_Count,3); % Index | X | Y

NumberOfRounds=5000;
TotalRoundList=zeros(NumberOfRounds,21); % 1: RoundNumber | 2: Minimum distance between actors | 3: Maximum distance between actors | 4: Average distance between actors | 5: Minimum distance between nodes | 6: Maximum distance between nodes | 7: Average distance between nodes | 8: Average data of the actors | 9: Average data of the nodes | 10: Average remaining energy of the nodes | 11: Total consumption energy of the nodes | 12: Average consumption energy of the nodes | 13: QOD | 14: Live nodes count | 15: Dead nodes count | 16: Filled buffer count of the nodes | 17: Filled buffer average of the nodes | 18: Filled buffer percent of the nodes | 19: Filled buffer count of the BaseStation | 20: Filled buffer percent of the BaseStation | 21: Produced packet count
TotalRoundList_Index=0;
ProducedPacketCount=0;
PacketGeneration_Count=100;

Network_Length=200;
Network_Width=200;

ActorNumber=20;
ActorRange=30;
MaximumActorValidValue=40;
ActorList=zeros(ActorNumber,6); % ID | X | Y | Z | Data | RWP_Point_Index
Actor_ChangePosition_RoundNumber=100;

NodeNumber=100;
NodeRange=40;
NodeBufferSize=200;
NodeList=zeros(NodeNumber,10); % ID | X | Y | Z | RemainingEnergy | Data | Status (has sendable data or no) | Dead RoundNumber | Is Clusterhead (0=no, 1=yes) | Clusterhead_ID
%NodeBuffer=zeros(NodeNumber,NodeBufferSize);
NodeBuffer_Index=zeros(NodeNumber,1);
NodeInitiatorSeqNo=zeros(NodeNumber,1);
NodeNeighbors=zeros(NodeNumber,NodeNumber);
NodeNeighbors_Index=zeros(NodeNumber,1);
Neighbors_Clusterhead=zeros(NodeNumber,NodeNumber,3); % Neighbor_ID | RemainingEnergy | DistanceToBaseStation
Neighbors_Clusterhead_Index=zeros(NodeNumber,1);
NodeSummaryTable=zeros(NodeNumber,3); % Total accepted data | Total sended packets | Total received packets in the BaseStation side
Update_Neighbors_Clusterhead_RoundNumber=1000;
Update_Cluster_RoundNumber=100;

P=0.05;

BaseStation_X=100;
BaseStation_Y=100;
BaseStationBufferSize=20000;
BaseStation=[BaseStation_X BaseStation_Y]; % X | Y
%BaseStationBuffer=zeros(BaseStationBufferSize,1);
BaseStationBuffer_Index=0;

PacketSize=1000;
NodeThresholdEnergy=5*(10^(-9))*PacketSize;
d0=87.7;





%%%%% Initialize
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Set RWP points
for i=1:RWP_Point_Count
    RWP_Point(i,1)=i;     
end;

RWP_Point=RWPPointSet(RWP_Point);

%%% NodeBuffer
for i=1:NodeNumber
    for j=1:NodeBufferSize
        NodeBuffer(i,j).PacketType=''; % Request_Neighbors_CH | Response_Neighbors_CH | DATA
        NodeBuffer(i,j).Initiator_ID=0;
        NodeBuffer(i,j).InitiatorSeqNo=0;
        NodeBuffer(i,j).PartialRoute=[];
        NodeBuffer(i,j).RemainingEnergy=0;
        NodeBuffer(i,j).Data=0; % DistanceToBaseStation | Data
        NodeBuffer(i,j).StartSend_RoundNumber=0;
    end;
end;

%%% BaseStationBuffer
for i=1:BaseStationBufferSize
    BaseStationBuffer(i,1).PacketType=''; % DATA
    BaseStationBuffer(i,1).Initiator_ID=0;
    BaseStationBuffer(i,1).InitiatorSeqNo=0;
    BaseStationBuffer(i,1).PartialRoute=[];
    BaseStationBuffer(i,1).RemainingEnergy=0;
    BaseStationBuffer(i,1).Data=0; % Data
    BaseStationBuffer(i,1).StartSend_RoundNumber=0;
    BaseStationBuffer(i,1).FinishSend_RoundNumber=0;
    BaseStationBuffer(i,1).Total_RoundNumber=0;
end;

%%% Actor
ActorList=ActorListSet(ActorList);

for i=1:ActorNumber
    ActorList(i,1)=i;
    ActorList(i,2)=RWP_Point(ActorList(i,6),2);
    ActorList(i,3)=RWP_Point(ActorList(i,6),3);
end;

%%% NodeList
NodeList=NodeListSet(NodeList,Network_Length,Network_Width);

for i=1:NodeNumber
    NodeList(i,1)=i;
    NodeList(i,5)=InitialNodeEnergy;
    NodeList(i,6)=InitialTemperatureValue;     
end;

%%% PacketGeneration_List
PacketGeneration_List=zeros(1,PacketGeneration_Count);
PacketGeneration_List_Index=1;
PacketGeneration_List=PacketGenerationListSet(PacketGeneration_List);

%%% PacketGenerationRate
PacketGenerationRate=500:100:2000; 





%%%%% Cycle
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Continue_Flag=1;
RoundNumber=1;
while (Continue_Flag==1)&&(RoundNumber<=NumberOfRounds)
    
    SensedDataCount=0;    
    AcceptedDataCount=0;

    %%% NodeConsumptionEnergy
    NodeConsumptionEnergy=zeros(NodeNumber,1);
    for i=1:NodeNumber
        NodeConsumptionEnergy(i,1)=NodeList(i,5);
    end;     
    
    %%% Change current position of the actors
    for i=1:ActorNumber
        if mod(RoundNumber,Actor_ChangePosition_RoundNumber)==0
            if ActorList(i,6)<RWP_Point_Count
                ActorList(i,6)=ActorList(i,6)+1;
            else
                ActorList(i,6)=1;
            end;

            ActorList(i,2)=RWP_Point(ActorList(i,6),2);
            ActorList(i,3)=RWP_Point(ActorList(i,6),3);       
        end;
    end;    

    %%% Update NodeNeighbors
    NodeNeighbors=zeros(NodeNumber,NodeNumber);
    NodeNeighbors_Index=zeros(NodeNumber,1);    
    for i=1:NodeNumber
        for j=1:NodeNumber
            if i~=j
                Distance=sqrt(((NodeList(i,2)-NodeList(j,2))^2)+((NodeList(i,3)-NodeList(j,3))^2));
                if Distance<=NodeRange
                    NodeNeighbors_Index(i)=NodeNeighbors_Index(i)+1;                               
                    NodeNeighbors(i,NodeNeighbors_Index(i))=j;
                end;
            end;
        end;
    end; 
    
    %%% Clustering
    if (RoundNumber==1)||(mod(RoundNumber,Update_Cluster_RoundNumber)==0)
        % Select clusterheads
        for i=1:NodeNumber
            r=RoundNumber;
            T_n=(P*NodeList(i,5))/(1-(P*(mod(r,(1/P)))*InitialNodeEnergy));
            RandomNumber=rand(1);
            if RandomNumber<T_n
                NodeList(i,9)=1;
            else
                NodeList(i,9)=0;
            end;
        end;
    
        % Construct Clusters
        %/ Find the best Clusterhead
        for i=1:NodeNumber
            if NodeList(i,9)==0  
                % Decrease consumption energy of the non cluster head node to check the neighboring cluster heads with the broadcast process
                Distance=NodeRange;                        
                if Distance<=d0
                    NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                else
                    NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                end;    
                
                ClusterheadList=zeros(NodeNumber,2);
                ClusterheadList_Index=0;
                
                for j=1:NodeNeighbors_Index(i,1)
                    Neighbor_ID=NodeNeighbors(i,j);
                    
                    if NodeList(Neighbor_ID,9)==1
                        ClusterheadList_Index=ClusterheadList_Index+1;
                        
                        ClusterheadList(ClusterheadList_Index,1)=Neighbor_ID;                        
                        ClusterheadList(ClusterheadList_Index,2)=1/sqrt(((NodeList(i,2)-NodeList(Neighbor_ID,2))^2)+((NodeList(i,3)-NodeList(Neighbor_ID,3))^2));
                        
                        % Decrease consumption energy of the cluster head node to receive the broadcast
                        NodeList(Neighbor_ID,5)=NodeList(Neighbor_ID,5)-(50*(10^(-9))*PacketSize);
                        
                        % Decrease consumption energy of the cluster head node to send the response
                        Distance=sqrt(((NodeList(Neighbor_ID,2)-NodeList(i,2))^2)+((NodeList(Neighbor_ID,3)-NodeList(i,3))^2));                        
                        if Distance<=d0
                            NodeList(Neighbor_ID,5)=NodeList(Neighbor_ID,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                        else
                            NodeList(Neighbor_ID,5)=NodeList(Neighbor_ID,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                        end; 
                        
                        % Decrease consumption energy of the non cluster head node to receive the response
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize);                        
                    end;
                end;
                
                ClusterheadList=ClusterheadList(1:ClusterheadList_Index,:);
                ClusterheadList=sortrows(ClusterheadList,2);
                
                if ClusterheadList_Index~=0
                    NodeList(i,10)=ClusterheadList(ClusterheadList_Index,1);
                end;
            end;
        end;
    end;        

    %%% Send the My_Info packet to the neighboring clusterheads to update Neighbors_Clusterhead
    if (RoundNumber==1)||(mod(RoundNumber,Update_Neighbors_Clusterhead_RoundNumber)==0)
        for i=1:NodeNumber
            if NodeList(i,9)==1  

                for j=1:NodeNumber
                    if (i~=j)&&(NodeList(j,9)==1)&&(NodeBuffer_Index(j,1)<NodeBufferSize)
                        NodeBuffer_Index(j,1)=NodeBuffer_Index(j,1)+1;

                        NodeBuffer(j,NodeBuffer_Index(j,1)).PacketType='Request_Neighbors_CH';
                        NodeBuffer(j,NodeBuffer_Index(j,1)).Initiator_ID=i;
                        NodeBuffer(j,NodeBuffer_Index(j,1)).InitiatorSeqNo=0;                                
                        NodeBuffer(j,NodeBuffer_Index(j,1)).PartialRoute=[];
                        NodeBuffer(j,NodeBuffer_Index(j,1)).RemainingEnergy=0;
                        NodeBuffer(j,NodeBuffer_Index(j,1)).Data=0;
                        NodeBuffer(j,NodeBuffer_Index(j,1)).StartSend_RoundNumber=RoundNumber;
                        
                        % Decrease consumption energy of the sender node
                        Distance=sqrt(((NodeList(i,2)-NodeList(j,2))^2)+((NodeList(i,3)-NodeList(j,3))^2));                         
                        if Distance<=d0
                            NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                        else
                            NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                        end; 

                        % Decrease consumption energy of the receiver node
                        NodeList(j,5)=NodeList(j,5)-(50*(10^(-9))*PacketSize);                          
                    end;                                                          
                end;
                                
            end;
        end;        
    end;
    
    %%% Generate and transmit data  
    if length(strfind(PacketGenerationRate,RoundNumber))>0
        for i=1:ActorNumber
            ActorList(i,5)=PacketGeneration_List(1,PacketGeneration_List_Index);
            
            % PacketGeneration_List_Index
            if PacketGeneration_List_Index<PacketGeneration_Count
                PacketGeneration_List_Index=PacketGeneration_List_Index+1;
            else
                PacketGeneration_List_Index=1;
            end;
                        
            for j=1:NodeNumber
                Distance=sqrt(((ActorList(i,2)-NodeList(j,2))^2)+((ActorList(i,3)-NodeList(j,3))^2));
                if (Distance<=ActorRange)&&(NodeList(j,5)>NodeThresholdEnergy)
                    if ActorList(i,5)<=MaximumActorValidValue
                        NodeList(j,6)=ActorList(i,5);
                        NodeList(j,7)=1;    
                        
                        % Update remaining energy of the node
                        NodeList(j,5)=NodeList(j,5)-(50*(10^(-9))*PacketSize);
                        
                        AcceptedDataCount=AcceptedDataCount+1;
                        
                        % Update NodeSummaryTable
                        NodeSummaryTable(j,1)=NodeSummaryTable(j,1)+1;                        
                    end;
                    SensedDataCount=SensedDataCount+1;
                end;
            end;
        end; 
    end;
    
    %%% Transmit the existing data of the nodes buffer
    for i=1:NodeNumber
        % If there is a sensed data
        if NodeList(i,7)==1
            % Non clusterhead
            if NodeList(i,9)==0
                if NodeList(i,10)~=0
                    Clusterhead_ID=NodeList(i,10);

                    if NodeBuffer_Index(Clusterhead_ID,1)<NodeBufferSize
                        NodeBuffer_Index(Clusterhead_ID,1)=NodeBuffer_Index(Clusterhead_ID,1)+1;
                        NodeInitiatorSeqNo(i,1)=NodeInitiatorSeqNo(i,1)+1;
                        ProducedPacketCount=ProducedPacketCount+1; 
                    
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).PacketType='DATA';
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).Initiator_ID=i;
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).InitiatorSeqNo=NodeInitiatorSeqNo(i,1);                                
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).PartialRoute=[i];
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).RemainingEnergy=NodeList(i,5);
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).Data=NodeList(i,6);
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).StartSend_RoundNumber=RoundNumber;

                        NodeList(i,7)=0;
                        
                        % Update NodeSummaryTable
                        NodeSummaryTable(i,2)=NodeSummaryTable(i,2)+1;                          
                    end;
                    
                    % Decrease consumption energy of the node
                    Distance=sqrt(((NodeList(i,2)-NodeList(Clusterhead_ID,2))^2)+((NodeList(i,3)-NodeList(Clusterhead_ID,3))^2));                        
                    if Distance<=d0
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                    else
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                    end;
                    NodeList(Clusterhead_ID,5)=NodeList(Clusterhead_ID,5)-(50*(10^(-9))*PacketSize);
                end;
            
            % Clusterhead
            else               
                Distance=sqrt(((NodeList(i,2)-BaseStation(1))^2)+((NodeList(i,3)-BaseStation(2))^2)); 
                if Distance<=NodeRange
                    NodeInitiatorSeqNo(i,1)=NodeInitiatorSeqNo(i,1)+1;
                    ProducedPacketCount=ProducedPacketCount+1;                 
                        
                    if BaseStationBuffer_Index<BaseStationBufferSize                
                        BaseStationBuffer_Index=BaseStationBuffer_Index+1;

                        BaseStationBuffer(BaseStationBuffer_Index,1).PacketType='DATA';
                        BaseStationBuffer(BaseStationBuffer_Index,1).Initiator_ID=i;
                        BaseStationBuffer(BaseStationBuffer_Index,1).InitiatorSeqNo=NodeInitiatorSeqNo(i,1);
                        BaseStationBuffer(BaseStationBuffer_Index,1).PartialRoute=[i];
                        BaseStationBuffer(BaseStationBuffer_Index,1).RemainingEnergy=NodeList(i,5);
                        BaseStationBuffer(BaseStationBuffer_Index,1).Data=NodeList(i,6);
                        BaseStationBuffer(BaseStationBuffer_Index,1).StartSend_RoundNumber=RoundNumber;
                        BaseStationBuffer(BaseStationBuffer_Index,1).FinishSend_RoundNumber=RoundNumber;
                        BaseStationBuffer(BaseStationBuffer_Index,1).Total_RoundNumber=0;                       
                        
                        % Update NodeSummaryTable 
                        NodeSummaryTable(i,3)=NodeSummaryTable(i,3)+1;                            
                    end;
                    
                    NodeList(i,7)=0;
                    
                    % Decrease consumption energy of the node
                    Distance=sqrt(((NodeList(i,2)-BaseStation(1))^2)+((NodeList(i,3)-BaseStation(2))^2));                        
                    if Distance<=d0
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                    else
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                    end;                    
                else                                      
                    NextHop=SelectNextHop(NodeNumber,i,Neighbors_Clusterhead,Neighbors_Clusterhead_Index);
                    
                    if NextHop~=0                        
                        if NodeBuffer_Index(NextHop,1)<NodeBufferSize
                            NodeBuffer_Index(NextHop,1)=NodeBuffer_Index(NextHop,1)+1;
                            NodeInitiatorSeqNo(i,1)=NodeInitiatorSeqNo(i,1)+1;
                            ProducedPacketCount=ProducedPacketCount+1;                              

                            NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).PacketType='DATA';
                            NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).Initiator_ID=i;
                            NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).InitiatorSeqNo=NodeInitiatorSeqNo(i,1)+1;
                            NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).PartialRoute=[i];
                            NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).RemainingEnergy=NodeList(i,5);
                            NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).Data=NodeList(i,6);
                            NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).StartSend_RoundNumber=RoundNumber; 
                            
                            % Update NodeSummaryTable
                            NodeSummaryTable(i,2)=NodeSummaryTable(i,2)+1;                               
                        end; 
                        
                        NodeList(i,7)=0;
                        
                        % Decrease consumption energy of the node
                        Distance=NodeRange;                        
                        if Distance<=d0
                            NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                        else
                            NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                        end;                          
                        NodeList(NextHop,5)=NodeList(NextHop,5)-(50*(10^(-9))*PacketSize);
                    end;
                end;                
            end;
        
        % If there is the packet in the buffer
        elseif NodeBuffer_Index(i,1)>0
            % Non clusterhead
            if NodeList(i,9)==0
                if (strcmp(NodeBuffer(i,1).PacketType,'DATA')==1)&&(NodeList(i,10)~=0)
                    Clusterhead_ID=NodeList(i,10);

                    if NodeBuffer_Index(Clusterhead_ID,1)<NodeBufferSize
                        NodeBuffer_Index(Clusterhead_ID,1)=NodeBuffer_Index(Clusterhead_ID,1)+1;
                    
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).PacketType=NodeBuffer(i,1).PacketType;
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).Initiator_ID=NodeBuffer(i,1).Initiator_ID;
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).InitiatorSeqNo=NodeBuffer(i,1).InitiatorSeqNo;                                
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).PartialRoute=[NodeBuffer(i,1).PartialRoute i];
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).RemainingEnergy=NodeBuffer(i,1).RemainingEnergy;
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).Data=NodeBuffer(i,1).Data;
                        NodeBuffer(Clusterhead_ID,NodeBuffer_Index(Clusterhead_ID,1)).StartSend_RoundNumber=NodeBuffer(i,1).StartSend_RoundNumber;
                        
                        % Update NodeSummaryTable
                        NodeSummaryTable(NodeBuffer(i,1).Initiator_ID,2)=NodeSummaryTable(NodeBuffer(i,1).Initiator_ID,2)+1;                          
                    end;
                    
                    % Decrease consumption energy of the node
                    Distance=sqrt(((NodeList(i,2)-NodeList(Clusterhead_ID,2))^2)+((NodeList(i,3)-NodeList(Clusterhead_ID,3))^2));                        
                    if Distance<=d0
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                    else
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                    end;
                    NodeList(Clusterhead_ID,5)=NodeList(Clusterhead_ID,5)-(50*(10^(-9))*PacketSize);
                end;           
            % Clusterhead
            else
                if strcmp(NodeBuffer(i,1).PacketType,'Request_Neighbors_CH')==1
                    SenderNode_ID=NodeBuffer(i,1).Initiator_ID;                

                    if NodeBuffer_Index(SenderNode_ID,1)<NodeBufferSize
                        NodeBuffer_Index(SenderNode_ID,1)=NodeBuffer_Index(SenderNode_ID,1)+1;

                        NodeBuffer(SenderNode_ID,NodeBuffer_Index(SenderNode_ID,1)).PacketType='Response_Neighbors_CH';
                        NodeBuffer(SenderNode_ID,NodeBuffer_Index(SenderNode_ID,1)).Initiator_ID=i;
                        NodeBuffer(SenderNode_ID,NodeBuffer_Index(SenderNode_ID,1)).InitiatorSeqNo=0;                                
                        NodeBuffer(SenderNode_ID,NodeBuffer_Index(SenderNode_ID,1)).PartialRoute=[];
                        NodeBuffer(SenderNode_ID,NodeBuffer_Index(SenderNode_ID,1)).RemainingEnergy=NodeList(i,5);
                        NodeBuffer(SenderNode_ID,NodeBuffer_Index(SenderNode_ID,1)).Data=sqrt(((NodeList(i,2)-BaseStation(1))^2)+((NodeList(i,3)-BaseStation(2))^2));
                        NodeBuffer(SenderNode_ID,NodeBuffer_Index(SenderNode_ID,1)).StartSend_RoundNumber=RoundNumber;
                    end;

                    % Decrease consumption energy of the node
                    Distance=sqrt(((NodeList(i,2)-NodeList(SenderNode_ID,2))^2)+((NodeList(i,3)-NodeList(SenderNode_ID,3))^2));                        
                    if Distance<=d0
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                    else
                        NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                    end;
                    NodeList(SenderNode_ID,5)=NodeList(SenderNode_ID,5)-(50*(10^(-9))*PacketSize); 

                elseif strcmp(NodeBuffer(i,1).PacketType,'Response_Neighbors_CH')==1
                    SenderNode_ID=NodeBuffer(i,1).Initiator_ID;

                    FindFlag='False';
                    for j=1:Neighbors_Clusterhead_Index(i,1)
                        if Neighbors_Clusterhead(i,j,1)==SenderNode_ID
                            Neighbors_Clusterhead(i,j,2)=NodeBuffer(i,1).RemainingEnergy;
                            Neighbors_Clusterhead(i,j,3)=NodeBuffer(i,1).Data;

                            FindFlag='True';
                        end;
                    end;

                    if strcmp(FindFlag,'False')==1
                        Neighbors_Clusterhead_Index(i,1)=Neighbors_Clusterhead_Index(i,1)+1;

                        Neighbors_Clusterhead(i,Neighbors_Clusterhead_Index(i,1),1)=SenderNode_ID;
                        Neighbors_Clusterhead(i,Neighbors_Clusterhead_Index(i,1),2)=NodeBuffer(i,1).RemainingEnergy;
                        Neighbors_Clusterhead(i,Neighbors_Clusterhead_Index(i,1),3)=NodeBuffer(i,1).Data;                    
                    end;
                elseif strcmp(NodeBuffer(i,1).PacketType,'DATA')==1
                    Distance=sqrt(((NodeList(i,2)-BaseStation(1))^2)+((NodeList(i,3)-BaseStation(2))^2)); 
                    if Distance<=NodeRange
                        if BaseStationBuffer_Index<BaseStationBufferSize
                            BaseStationBuffer_Index=BaseStationBuffer_Index+1;

                            BaseStationBuffer(BaseStationBuffer_Index,1).PacketType=NodeBuffer(i,1).PacketType;
                            BaseStationBuffer(BaseStationBuffer_Index,1).Initiator_ID=NodeBuffer(i,1).Initiator_ID;
                            BaseStationBuffer(BaseStationBuffer_Index,1).InitiatorSeqNo=NodeBuffer(i,1).InitiatorSeqNo;
                            BaseStationBuffer(BaseStationBuffer_Index,1).PartialRoute=[NodeBuffer(i,1).PartialRoute i];
                            BaseStationBuffer(BaseStationBuffer_Index,1).RemainingEnergy=NodeBuffer(i,1).RemainingEnergy;
                            BaseStationBuffer(BaseStationBuffer_Index,1).Data=NodeBuffer(i,1).Data;
                            BaseStationBuffer(BaseStationBuffer_Index,1).StartSend_RoundNumber=NodeBuffer(i,1).StartSend_RoundNumber;
                            BaseStationBuffer(BaseStationBuffer_Index,1).FinishSend_RoundNumber=RoundNumber;
                            BaseStationBuffer(BaseStationBuffer_Index,1).Total_RoundNumber=RoundNumber-NodeBuffer(i,1).StartSend_RoundNumber;

                            % Update NodeSummaryTable 
                            NodeSummaryTable(NodeBuffer(i,1).Initiator_ID,3)=NodeSummaryTable(NodeBuffer(i,1).Initiator_ID,3)+1;                            
                        end;  

                        % Decrease consumption energy of the node
                        Distance=sqrt(((NodeList(i,2)-BaseStation(1))^2)+((NodeList(i,3)-BaseStation(2))^2));                        
                        if Distance<=d0
                            NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                        else
                            NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                        end;                      
                    else
                        NextHop=SelectNextHop(NodeNumber,i,Neighbors_Clusterhead,Neighbors_Clusterhead_Index);

                        if NextHop~=0
                            if NodeBuffer_Index(NextHop,1)<NodeBufferSize
                                NodeBuffer_Index(NextHop,1)=NodeBuffer_Index(NextHop,1)+1;

                                NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).PacketType=NodeBuffer(i,1).PacketType;
                                NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).Initiator_ID=NodeBuffer(i,1).Initiator_ID;
                                NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).InitiatorSeqNo=NodeBuffer(i,1).InitiatorSeqNo;
                                NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).PartialRoute=[NodeBuffer(i,1).PartialRoute i];
                                NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).RemainingEnergy=NodeBuffer(i,1).RemainingEnergy;
                                NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).Data=NodeBuffer(i,1).Data;
                                NodeBuffer(NextHop,NodeBuffer_Index(NextHop,1)).StartSend_RoundNumber=NodeBuffer(i,1).StartSend_RoundNumber;                          

                                % Update NodeSummaryTable 
                                NodeSummaryTable(NodeBuffer(i,1).Initiator_ID,2)=NodeSummaryTable(NodeBuffer(i,1).Initiator_ID,2)+1;                               
                            end; 

                            % Decrease consumption energy of the node
                            Distance=NodeRange;                        
                            if Distance<=d0
                                NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+10*(10^(-12))*PacketSize*(Distance^2));
                            else
                                NodeList(i,5)=NodeList(i,5)-(50*(10^(-9))*PacketSize+13*(10^(-16))*PacketSize*(Distance^4));
                            end;                         
                            NodeList(NextHop,5)=NodeList(NextHop,5)-(50*(10^(-9))*PacketSize);                        
                        end;                   
                    end; 
                end;                 
            end;            
            
            % Delete packet from NodeBuffer
            NodeBuffer_Index(i,1)=NodeBuffer_Index(i,1)-1;
            for k=1:NodeBuffer_Index(i,1)
                NodeBuffer(i,k)=NodeBuffer(i,k+1);
            end;             
        end;
    end;
        
    %%% TotalRoundList
    TotalRoundList(RoundNumber,1)=RoundNumber;    
    % 
    Distance=zeros(1,ActorNumber^2);
    Distance_Index=0;
    for i=1:ActorNumber
        for j=1:ActorNumber
            if i<j
                Distance_Index=Distance_Index+1;
                
                Distance_Value=sqrt(((ActorList(i,2)-ActorList(j,2))^2)+((ActorList(i,3)-ActorList(j,3))^2));
                Distance(1,Distance_Index)=Distance_Value;
            end;
        end;
    end;
    TotalRoundList(RoundNumber,2)=min(Distance(1,1:Distance_Index)); 
    % 
    Distance=zeros(1,ActorNumber^2);
    Distance_Index=0;
    for i=1:ActorNumber
        for j=1:ActorNumber
            if i<j
                Distance_Index=Distance_Index+1;
                
                Distance_Value=sqrt(((ActorList(i,2)-ActorList(j,2))^2)+((ActorList(i,3)-ActorList(j,3))^2));
                Distance(1,Distance_Index)=Distance_Value;
            end;
        end;
    end;
    TotalRoundList(RoundNumber,3)=max(Distance(1,1:Distance_Index)); 
    % 
    Distance=zeros(1,ActorNumber^2);
    Distance_Index=0;
    for i=1:ActorNumber
        for j=1:ActorNumber
            if i<j
                Distance_Index=Distance_Index+1;
                
                Distance_Value=sqrt(((ActorList(i,2)-ActorList(j,2))^2)+((ActorList(i,3)-ActorList(j,3))^2));
                Distance(1,Distance_Index)=Distance_Value;
            end;
        end;
    end;
    TotalRoundList(RoundNumber,4)=round((sum(Distance(1,1:Distance_Index)))/ActorNumber);     
    % 
    Distance=zeros(1,NodeNumber^2);
    Distance_Index=0;
    for i=1:NodeNumber
        for j=1:NodeNumber
            if i<j
                Distance_Index=Distance_Index+1;
                
                Distance_Value=sqrt(((NodeList(i,2)-NodeList(j,2))^2)+((NodeList(i,3)-NodeList(j,3))^2));
                Distance(1,Distance_Index)=Distance_Value;
            end;
        end;
    end;
    TotalRoundList(RoundNumber,5)=min(Distance(1,1:Distance_Index)); 
    %
    Distance=zeros(1,NodeNumber^2);
    Distance_Index=0;
    for i=1:NodeNumber
        for j=1:NodeNumber
            if i<j
                Distance_Index=Distance_Index+1;
                
                Distance_Value=sqrt(((NodeList(i,2)-NodeList(j,2))^2)+((NodeList(i,3)-NodeList(j,3))^2));
                Distance(1,Distance_Index)=Distance_Value;
            end;
        end;
    end;
    TotalRoundList(RoundNumber,6)=max(Distance(1,1:Distance_Index)); 
    %
    Distance=zeros(1,NodeNumber^2);
    Distance_Index=0;
    for i=1:NodeNumber
        for j=1:NodeNumber
            if i<j
                Distance_Index=Distance_Index+1;
                
                Distance_Value=sqrt(((NodeList(i,2)-NodeList(j,2))^2)+((NodeList(i,3)-NodeList(j,3))^2));
                Distance(1,Distance_Index)=Distance_Value;
            end;
        end;
    end;
    TotalRoundList(RoundNumber,7)=round((sum(Distance(1,1:Distance_Index)))/NodeNumber);
    %
    Sum=0;
    for i=1:ActorNumber
        Sum=Sum+ActorList(i,5);
    end;
    TotalRoundList(RoundNumber,8)=Sum/ActorNumber; 
    %
    Sum=0;
    for i=1:NodeNumber
        Sum=Sum+NodeList(i,6);
    end;
    TotalRoundList(RoundNumber,9)=Sum/NodeNumber;            
    %
    Sum=0;
    for i=1:NodeNumber
        Sum=Sum+NodeList(i,5);
    end;
    if (Sum/NodeNumber)>NodeThresholdEnergy
        TotalRoundList(RoundNumber,10)=Sum/NodeNumber;    
    else
        TotalRoundList(RoundNumber,10)=NodeThresholdEnergy;
    end;   
    %
    for i=1:NodeNumber
        NodeConsumptionEnergy(i,1)=NodeConsumptionEnergy(i,1)-NodeList(i,5);
    end;    
    Sum=0;
    for i=1:NodeNumber
        Sum=Sum+NodeConsumptionEnergy(i,1);
    end;
    TotalRoundList(RoundNumber,11)=Sum;    
    %
    TotalRoundList(RoundNumber,12)=TotalRoundList(RoundNumber,11)/NodeNumber;
    %
    if SensedDataCount>0
        TotalRoundList(RoundNumber,13)=(AcceptedDataCount/SensedDataCount)*100;
    else
        TotalRoundList(RoundNumber,13)=0;
    end;
    %
    Count=0;
    for i=1:NodeNumber
        if NodeList(i,5)>NodeThresholdEnergy
            Count=Count+1;
        end;
    end;
    TotalRoundList(RoundNumber,14)=Count; 
    %
    TotalRoundList(RoundNumber,15)=NodeNumber-TotalRoundList(RoundNumber,14);        
    %
    Sum=0;
    for i=1:NodeNumber
        Sum=Sum+NodeBuffer_Index(i,1);
    end; 
    TotalRoundList(RoundNumber,16)=Sum; 
    %
    TotalRoundList(RoundNumber,17)=TotalRoundList(RoundNumber,16)/NodeNumber;    
    %
    TotalRoundList(RoundNumber,18)=(TotalRoundList(RoundNumber,16)/(NodeNumber*NodeBufferSize))*100;                 
    % 
    TotalRoundList(RoundNumber,19)=BaseStationBuffer_Index;     
    % 
    TotalRoundList(RoundNumber,20)=BaseStationBuffer_Index/BaseStationBufferSize;     
    % 
    TotalRoundList(RoundNumber,21)=ProducedPacketCount;
    
    %%% Check dead state of the nodes
    for i=1:NodeNumber
        if (NodeList(i,8)==0)&&(NodeList(i,5)<NodeThresholdEnergy)
            NodeList(i,8)=RoundNumber;    
        end;
    end; 
    
    %%% Check dead state of the nodes
    if TotalRoundList(RoundNumber,15)>=(NodeNumber/2)
        Continue_Flag=0;
    end;    
    
    %%% Display and increase RoundNumber
    RoundNumber
    RoundNumber=RoundNumber+1;       
end; 





%%%%% Display summary tables and charts of the rounds
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
%%% Summary table
TotalRoundList=TotalRoundList(1:(RoundNumber-1),:);
TotalRoundList

%%% Charts
% Average remaining energy of the nodes
figure(1);
plot(TotalRoundList(:,1),TotalRoundList(:,10),'-b','LineWidth',2);
title('Average Remaining Energy of the Nodes');
xlabel('Round Number');
ylabel('Average Energy (Joule)');

% Total consumption energy of the nodes
figure(2);
plot(TotalRoundList(:,1),TotalRoundList(:,11),'-r','LineWidth',2);
title('Total Consumption Energy of the Nodes');
xlabel('Round Number');
ylabel('Total Consumption Energy (Joule)'); 

% Average consumption energy of the nodes
figure(3);
plot(TotalRoundList(:,1),TotalRoundList(:,12),'-k','LineWidth',2);
title('Average Consumption Energy of the Nodes');
xlabel('Round Number');
ylabel('Average of Consumption Energy (Joule)');     

% Live nodes count
figure(4);
plot(TotalRoundList(:,1),TotalRoundList(:,14),'-b','LineWidth',2);
title('Number of Live Nodes');
xlabel('Round Number');
ylabel('Number of Live Nodes');    

% Filled buffer count of the nodes
figure(5);
plot(TotalRoundList(:,1),TotalRoundList(:,16),'-r','LineWidth',2);
title('Filled Buffer Count of the Nodes');
xlabel('Round Number');
ylabel('Number of Filled Buffer');   

% Filled buffer average of the nodes
figure(6);
plot(TotalRoundList(:,1),TotalRoundList(:,17),'-k','LineWidth',2);
title('Filled Buffer Average of the Nodes');
xlabel('Round Number');
ylabel('Average of Filled Buffer'); 

% Filled buffer percent of the nodes
figure(7);
plot(TotalRoundList(:,1),TotalRoundList(:,18),'-m','LineWidth',2);
title('Filled Buffer Percent of the Nodes');
xlabel('Round Number');
ylabel('Percent of Filled Buffer (%)'); 

% Filled buffer count of the base station
figure(8);
plot(TotalRoundList(:,1),TotalRoundList(:,19),'-b','LineWidth',2);
title('Filled Buffer Count of the Base Station');
xlabel('Round Number');
ylabel('Number of Filled Buffer');     





%%%%% Set NodeThresholdEnergy of the deaded nodes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:NodeNumber
    if NodeList(i,5)<NodeThresholdEnergy
        NodeList(i,5)=NodeThresholdEnergy;
    end;
end;





%%%%% Display summary tables and charts of the BaseStation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Summary table
TotalBaseStationDataList=zeros(BaseStationBuffer_Index,8); % 1: PacketNumber | 2: Initiator_ID | 3: InitiatorSeqNo | 4: IntermediateNodesCount | 5:RemainingEnergy | 6: Data | 7: StartSend_RoundNumber | 8: FinishSend_RoundNumber | 9: Total_RoundNumber
for i=1:BaseStationBuffer_Index
    TotalBaseStationDataList(i,1)=i;
    TotalBaseStationDataList(i,2)=BaseStationBuffer(i,1).Initiator_ID;
    TotalBaseStationDataList(i,3)=BaseStationBuffer(i,1).InitiatorSeqNo;
    TotalBaseStationDataList(i,4)=length(BaseStationBuffer(i,1).PartialRoute);
    TotalBaseStationDataList(i,5)=BaseStationBuffer(i,1).RemainingEnergy;
    TotalBaseStationDataList(i,6)=BaseStationBuffer(i,1).Data;
    TotalBaseStationDataList(i,7)=BaseStationBuffer(i,1).StartSend_RoundNumber;
    TotalBaseStationDataList(i,8)=BaseStationBuffer(i,1).FinishSend_RoundNumber;
    TotalBaseStationDataList(i,9)=BaseStationBuffer(i,1).Total_RoundNumber;        
end;
TotalBaseStationDataList


            


%%%%% Display summary tables and charts of the nodes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

%%% Summary table
NodeList
NodeSummaryTable
    
%%% Charts
figure(9);
hold on;

ClusterNode=zeros(NodeNumber,3);
ClusterNode_Index=0;
NonClusterNode=zeros(NodeNumber,3);
NonClusterNode_Index=0;

for i=1:NodeNumber
    if NodeList(i,9)==1
        ClusterNode_Index=ClusterNode_Index+1;
        
        ClusterNode(ClusterNode_Index,1)=i;
        ClusterNode(ClusterNode_Index,2)=NodeList(i,2);
        ClusterNode(ClusterNode_Index,3)=NodeList(i,3);
    else
        NonClusterNode_Index=NonClusterNode_Index+1;
        
        NonClusterNode(NonClusterNode_Index,1)=i;
        NonClusterNode(NonClusterNode_Index,2)=NodeList(i,2);
        NonClusterNode(NonClusterNode_Index,3)=NodeList(i,3);        
    end;
end;
ClusterNode=ClusterNode(1:ClusterNode_Index,:);
NonClusterNode=NonClusterNode(1:NonClusterNode_Index,:);

plot(ClusterNode(:,2),ClusterNode(:,3),'o','MarkerFaceColor','r','MarkerSize',10);
plot(NonClusterNode(:,2),NonClusterNode(:,3),'o','MarkerFaceColor','b','MarkerSize',10);
plot(BaseStation(1),BaseStation(2),'s','MarkerEdgeColor','k','MarkerFaceColor','k','MarkerSize',15);

for i=1:ClusterNode_Index
    [X Y]=DrawCircle(ClusterNode(i,2),ClusterNode(i,3),NodeRange);
    plot(X,Y,'o','MarkerEdgeColor','r','MarkerFaceColor','r','MarkerSize',1);
end;

hold off;
grid on;
title('Position of the Nodes');
xlabel('X');
ylabel('Y');
 




%%%%% Display single outputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    

% Number of Produced Packets
ProducedPacketCount

% Number of Delivered Packets
DeliveredPacketCount=BaseStationBuffer_Index

% Number of Lost Packets
LostPacketCount=ProducedPacketCount-DeliveredPacketCount

% Packet Delivery Ratio
PacketDeliveryRatio=(DeliveredPacketCount/ProducedPacketCount)*100

% Number of Alive Nodes
Count=0;
for i=1:NodeNumber
    if NodeList(i,5)>NodeThresholdEnergy
        Count=Count+1;    
    end;
end; 
NumberOfAliveNodes=Count

% Average Remaining Energy
AverageRemainingEnergy=TotalRoundList(RoundNumber-1,10)

% Packet Delivery Latency
SumLatency=0;
for i=1:BaseStationBuffer_Index
    SumLatency=SumLatency+BaseStationBuffer(i,1).Total_RoundNumber;    
end; 
PacketDeliveryLatency=SumLatency/BaseStationBuffer_Index
