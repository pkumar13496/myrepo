global class ApplicationExecutionAction{
    
    genesis__Applications__c app;
    Id applicationId;
    public static Integer actionCount = 0;
    List<Execution_Flow_Action_Junction__c> exeFlowActionJunction;
    JWF_Application_Execution_Log__c appExecutionLog;
    public ApplicationExecutionAction(Id applicationId){
        
        this.applicationId = applicationId;
        //queryApplication(applicationId);    
    }
    
    public void queryApplication(Id applicationId){
        
        app = [Select Id,
               genesis__CL_Product__c,
               genesis__CL_Product__r.JWF_Execution_Flow__c,
               genesis__Status__c,
               Execution_Flow__c,
               (Select id,
                        Sequence__c,
                        Action_Status__c,Action_Name__c,
                        Message__c
                From JWF_Execution_Logs__r
                Where Action_Status__c = 'In Progress' limit 1)
               From genesis__Applications__c
               Where Id = :applicationId ];
        appExecutionLog = new JWF_Application_Execution_Log__c();
    }
    
    public void doInvokeAction(Map<String,Object> paramMap){
        queryApplication(applicationId);
        system.debug('--paramMap--'+paramMap);
        List<genesis__Checklist__c> checklist;
        String action = (paramMap != null && paramMap.get('Action') != null) ? (String)paramMap.get('Action') : 'Approve';
        try{
            if(app.Execution_Flow__c == null && app.genesis__CL_Product__r.JWF_Execution_Flow__c != null){
                app.Execution_Flow__c = app.genesis__CL_Product__r.JWF_Execution_Flow__c;
                SecureDML.updateRecords(app);
            }
            if(app.Execution_Flow__c == null){
                throw (new CustomException('JWF Execution flow is not assosiated to the Application or CL Product'));    
            }
            
            System.debug(app.Execution_Flow__c);
            System.debug('--App Current Status--'+app.genesis__Status__c);
            exeFlowActionJunction = [Select Id,
                                     Action__c,
                                     Action__r.Name,
                                     Action__r.Class_Action_Name__c,
                                     Action__r.Rule__c,
                                     Action__r.CLCommon_Rule__c,
                                     Action__r.Action_Type__c,
                                     Current_Status__c,
                                     Next_Status__c,
                                     Transiction__c,
                                     Transition_Type__c,
                                     Sequence__c
                                     From Execution_Flow_Action_Junction__c
                                     Where Execution_Flow__c = :app.Execution_Flow__c
                                     AND Current_Status__c = :app.genesis__Status__c
                                     AND Transiction__c = :action
                                     AND Execution_Flow__r.Active__c = true ] ;
            
            system.debug(exeFlowActionJunction);
            if( exeFlowActionJunction == null || exeFlowActionJunction.size() == 0){
                throw (new CustomException('JWF Execution Flow is not active or action row is missing for status - '+app.genesis__Status__c));
            }    
            
            if(null != paramMap && null != paramMap.get('appExecutionLog')){
                system.debug('--appExecutionLog--'+appExecutionLog);
                appExecutionLog = (JWF_Application_Execution_Log__c)paramMap.get('appExecutionLog');
            }else{
                for(JWF_Application_Execution_Log__c appLog : app.JWF_Execution_Logs__r){
                    if(appLog.Sequence__c.equalsIgnoreCase(exeFlowActionJunction[0].Sequence__c)){
                        appExecutionLog = appLog;
                        system.debug('--appExecutionLog--'+appExecutionLog);
                    }
                }    
            }
            system.debug('-appExecutionLog-'+appExecutionLog);
            
            //get the next status from the Execution_Flow_Action_Junction__c table
            //update app status to next status from Execution_Flow_Action_Junction__c table
            //app.genesis__Status__c = exeFlowActionJunction[0].Next_Status__c;
            
            
            //perform the next action 
            //Next action = exeFlowActionJunction[0].Action__r.Name 
            
            String nextAction = exeFlowActionJunction[0].Action__r.Class_Action_Name__c;
            system.debug('--nextAction--'+nextAction);
            
            Boolean allowNextAction = false;
            //check if next action can be performed.
            //Evaluate the rules for this action.
            if(exeFlowActionJunction[0].Action__r.Rule__c != null){
                
                List<genesis__Rule__c> ruleList = [Select Id 
                                                   from genesis__Rule__c
                                                   Where Id = :exeFlowActionJunction[0].Action__r.Rule__c];
                
                checklist = genesis.RulesAPI.evaluateRules(app,ruleList,true,true);
                system.debug(checklist);
                if(checklist != null && checklist.size() > 0){
                    if(checklist[0].genesis__Result__c){
                        allowNextAction = true;    
                    }
                }
                
            }else if(exeFlowActionJunction[0].Action__r.CLCommon_Rule__c != null){
                // Calling the RuleEngine for processing the Rule attached to
                List<clcommon__Rule__c> clCommonRulesList =  [SELECT Id, Name,
                                                              clcommon__Enabled__c,
                                                              clcommon__Object_Type__c,
                                                              clcommon__Parent_Rule__c,
                                                              clcommon__Rule_Json__c,
                                                              clcommon__Rule_Priority__c,
                                                              clcommon__Rule_Set__c
                                                              FROM clcommon__Rule__c
                                                              WHERE Id = :exeFlowActionJunction[0].Action__r.CLCommon_Rule__c
                                                              AND clcommon__Enabled__c = true ];
                
                //Need to remove 
                System.debug('id check'+ exeFlowActionJunction[0].Action__r.CLCommon_Rule__c);
                if(clCommonRulesList!=null && clCommonRulesList.size() > 0) {
                    
                    system.debug('clCommonRulesList.size()=='+clCommonRulesList.size());
                    
                    clcommon.RulesAPI2 rulesIns = clcommon.APIFactory.getRulesAPI2();
                    rulesIns.setIDs(new set<Id> {applicationId});
                    rulesIns.setRules(clCommonRulesList);
                    rulesIns.evaluate();
                    
                    Map<String,Set<Id>> failedRecords =  rulesIns.getFailureRecIds();
                    
                    system.debug('failedRecords.size()=='+failedRecords.size());
                    system.debug('failedRecords.keySet()=='+failedRecords.keySet());
                    // throwing exception incase of any failed rules associated.
                    if(failedRecords.size() > 0) {
                        system.debug('Evaluation criteria with Following rule association with Status Change failed '+ failedRecords.keySet());
                        allowNextAction = false;
                    }else{
                        allowNextAction = true;   
                    }
                }
            }else{
                //No rule defined. Hence no need to check for validation. Always run the action.
                allowNextAction = true;
            }
            
            if(allowNextAction){
                if(exeFlowActionJunction[0].Action__r.Action_Type__c.equalsIgnoreCase('Auto')){
                    if(exeFlowActionJunction[0].Transition_Type__c.equalsIgnoreCase('Synchronous')){
                        Type t = Type.forName(nextAction);
                        if(t != null){
                            appExecutionLog = insertAppExecutionLog('Action '+nextAction+' has started.', appExecutionLog, 'In Progress');
                            actionCount++;
                            IFlowExecution impl = (IFlowExecution)t.newInstance();
                            impl.execute(app.Id, appExecutionLog); 
                        }else{
                            throw (new CustomException('Implementation is missing for '+nextAction));
                        }
                    }else{
                        //Asynchronous call, publish platform event.
                        appExecutionLog = insertAppExecutionLog('Action '+nextAction+' has started.', appExecutionLog, 'In Progress');
                        actionCount++;
                        publishEvent(nextAction, appExecutionLog.Id);
                    }
                }else{
                    //check if this is last step in the application.
                    if(!nextAction.equalsIgnoreCase('Manual END')){
                        //move to next status after manual step.
                        Map<String,Object> statusParamMap = new Map<String,Object>();
                        
                        system.debug('-appExecutionLog-'+appExecutionLog);
                        if(appExecutionLog.Id != null){
                            system.debug('--appExecutionLog not null. add existing.'+appExecutionLog);
                            statusParamMap.put('appExecutionLog',appExecutionLog);
                        }else{
                            appExecutionLog = insertAppExecutionLog('Action '+nextAction+' has started.', appExecutionLog, 'In Progress');
                            system.debug('--appExecutionLog null.create new. '+appExecutionLog);
                            statusParamMap.put('appExecutionLog',appExecutionLog);
                        }
                        //appExecutionLog = insertAppExecutionLog('Action '+nextAction+' has started.', appExecutionLog, 'In Progress');
                        system.debug('--statusParamMap--'+statusParamMap);
                        system.debug('--actionCount--'+actionCount);
                       
                        for(String str : statusParamMap.keySet()){
                             system.debug('--str--'+str+'-value-'+statusParamMap.get(str));    
                        }
                        if(actionCount ==0){
                            changeStatus(statusParamMap);
                            //changeStatus(null);
                            actionCount++;
                            //Invoke next action
                            doInvokeAction(null);    
                        }
                        
                    }else{
                        //do nothing.
                    }
                }
                
            }else{
                system.debug('Not allowed to perform the next action.');
                throw (new CustomException('Not allowed to perform the next action.'));
            }
        }catch(Exception exp){
            appExecutionLog = insertAppExecutionLog('Action for the status '+app.genesis__Status__c+' has been failed.'+'Exception '+ exp+exp.getLineNumber() +' Rule result '+checklist, 
                                                    appExecutionLog, 
                                                    'Failed'); 
           // throw (new CustomException(exp.getMessage()));
        }
    }
    
    public Map<String,Object> changeStatus(Map<String,Object> paramMap){
        Map<String,Object> returnMap = new Map<String,Object>();
        
        system.debug('--paramMap--'+paramMap);
        queryApplication(applicationId);
        String action = (paramMap != null && paramMap.get('Action') != null) ? (String)paramMap.get('Action') : 'Approve';
        system.debug('--app--'+app);
        System.debug(app.Execution_Flow__c);
        System.debug('--App current status--'+app.genesis__Status__c);
        List<Execution_Flow_Action_Junction__c> exeFlowActionJunction = [Select Id,
                                                                         Action__c,
                                                                         Action__r.Name,
                                                                         Action__r.Rule__c,
                                                                         Current_Status__c,
                                                                         Next_Status__c,
                                                                         Transiction__c,
                                                                         Transition_Type__c,
                                                                         Sequence__c
                                                                         From Execution_Flow_Action_Junction__c
                                                                         Where Execution_Flow__c = :app.Execution_Flow__c
                                                                         AND Current_Status__c = :app.genesis__Status__c
                                                                         AND Transiction__c = :action
                                                                         AND Execution_Flow__r.Active__c = true ] ;
        
        if( exeFlowActionJunction == null || exeFlowActionJunction.size() == 0){
            throw (new CustomException('There is no Active flow assosiated to the application.'));
        }                                                                  
        system.debug(exeFlowActionJunction);
        //get the next status from the Execution_Flow_Action_Junction__c table
        //update app status to next status from Execution_Flow_Action_Junction__c table
        app.genesis__Status__c = exeFlowActionJunction[0].Next_Status__c;
        SecureDML.updateRecords(app);  
        
        //Complete the AppExecutionLog
        if(null != paramMap && 
            null != paramMap.get('appExecutionLog') ){
            appExecutionLog = (JWF_Application_Execution_Log__c)paramMap.get('appExecutionLog');
           
            if(exeFlowActionJunction[0].Action__r.Name == appExecutionLog.Action_Name__c){
                appExecutionLog.Sequence__c= exeFlowActionJunction[0].Sequence__c; //WorkAround 14Sept Nikhil
            }    
        }else{
            //List<JWF_Application_Execution_Log__c> appExecutionLogs = app.JWF_Execution_Logs__r;
            system.debug('--appExecutionLogs--'+app.JWF_Execution_Logs__r);
            //List<JWF_Application_Execution_Log__c> appExecutionLogsToBeUpdated = new List<JWF_Application_Execution_Log__c>();
             
            for(JWF_Application_Execution_Log__c appLog : app.JWF_Execution_Logs__r){
                if(exeFlowActionJunction[0].Action__r.Name == appLog.Action_Name__c){
                    appLog.Sequence__c= exeFlowActionJunction[0].Sequence__c; //WorkAround 14Sept Nikhil
                }                
                system.debug('--appExecutionLog.Sequence__c--'+appLog.Sequence__c+'-exeFlowActionJunction[0].Sequence__c-'+exeFlowActionJunction[0].Sequence__c);
                if(appLog.Sequence__c.equalsIgnoreCase(exeFlowActionJunction[0].Sequence__c)){
                    system.debug('app log if condition');
                    appExecutionLog = appLog;
                    //appExecutionLogsToBeUpdated.add(appExecutionLog);    
                }
            } 
            /*system.debug('--appExecutionLogsToBeUpdated--'+appExecutionLogsToBeUpdated);
            if(appExecutionLogsToBeUpdated != null && appExecutionLogsToBeUpdated.size() > 0){
                SecureDML.updateRecords(appExecutionLogsToBeUpdated);
            } */      
        } 
        
        system.debug('Jitu execution log '+appExecutionLog);
        
        appExecutionLog.Message__c += ' Action has been completed.' ;   
        appExecutionLog.Action_Status__c = 'Completed';
        SecureDML.updateRecords(appExecutionLog);
        //Call next action
        Boolean callNextAction = (paramMap != null && paramMap.get('callNextAction') != null) ? (Boolean)paramMap.get('callNextAction') : false;
        if(callNextAction){
            doInvokeAction(null);
        }
        returnMap.put('appExecutionLog',appExecutionLog);
        return returnMap;
    }
    
    private void publishEvent(String eventType, Id executionLogId) {
        Application_Execution_Event__e appEvent = new Application_Execution_Event__e (
            Record_Ids__c = app.Id,
            Event_Type__c = eventType,
            Execution_Log_Id__c = executionLogId
        );
        // Call method to publish events.
        Database.SaveResult result = EventBus.publish(appEvent);
        
        // Inspect publishing result for the event
        if (result.isSuccess()) {
            System.debug(Logginglevel.ERROR, 'Error in Application Execution Event'+ new List<String>{app.Id});
        }else {
            for (Database.Error err : result.getErrors()) {
                System.debug(Logginglevel.ERROR, 'Error in Application Execution Event App Id - '+
                             err.getStatusCode() +
                             ' - ' +
                             err.getMessage());
            }
        }
    }
    

    webservice static void exceuteFlow(String appId){
        ApplicationExecutionAction action = new ApplicationExecutionAction(appId);
        action.doInvokeAction(null);
    } 

    webservice static void exceuteFlowWithTransition(String appId, String actionTransition){
        ApplicationExecutionAction action = new ApplicationExecutionAction(appId);
        Map<String,Object> paramMap = new Map<String,Object>();
        paramMap.put('Action',actionTransition);
        action.doInvokeAction(null);
    } 


    public JWF_Application_Execution_Log__c insertAppExecutionLog(String message, JWF_Application_Execution_Log__c appExecutionLog, String actionStatus){
        Boolean createNewRecord = false;
        if(appExecutionLog.Id == null){
            createNewRecord = true; 
        }
        if(createNewRecord){
            //there is no record for this action. Create new.
            //appExecutionLog = new JWF_Application_Execution_Log__c();
            appExecutionLog.Action_Status__c = actionStatus; 
            appExecutionLog.Message__c = message; 
            appExecutionLog.Application__c = applicationId;
            if(exeFlowActionJunction != null && exeFlowActionJunction.size() > 0){
                appExecutionLog.Action_Name__c = exeFlowActionJunction[0].Action__r.Name;
                appExecutionLog.Sequence__c = exeFlowActionJunction[0].Sequence__c; 
            }
            SecureDML.insertRecords(appExecutionLog); 
        } else{
            //update the existing record.
            if(!appExecutionLog.Action_Status__c.equalsIgnoreCase('Completed')){
                appExecutionLog.Message__c = message;
                appExecutionLog.Action_Status__c = actionStatus;
                SecureDML.updateRecords(appExecutionLog);
            }       
        }
        system.debug('--appExecutionLog--'+appExecutionLog);
        return appExecutionLog;
    }         
}