global class APOriginationAmountCalculator{
    
    Webservice Static String calculate(String applicationId){
        genesis__applications__c app;
        List<genesis__applications__c> applications = [SELECT id,Name,
                                                       New_H_A__c,
                                                       H_A_Amount__c,
                                                       H_A_Plan_Base_Amount__c,
                                                       H_A_Plan_Tax_Rate_Amount__c,
                                                       H_A_Renewal__c,
                                                       Total_H_A_Plan_Amount__c,
                                                       Credit_Monitoring__c,
                                                       CM_Base_Amount__c,
                                                       CM_Tax_Rate_Amount__c,
                                                       Total_CM_Amount__c,
                                                       Loan_Protection_Plan__c,
                                                       LPP_Base_Amount__c,
                                                       LPP_Tax_Rate_Amount__c,
                                                       Total_LPP_Amount__c,
                                                       genesis__Total_Estimated_Interest__c,
                                                       Term_Type__c,
                                                       genesis__Payment_Frequency__c,
                                                       Home_Auto_Term__c,
                                                       H_A_Type__c,
                                                       genesis__Loan_Amount__c,
                                                       genesis__Account__r.id 
                                                       FROM genesis__applications__c
                                                       WHERE id = : applicationId ];
        if(applications.size() == 0){
            return 'ERROR: Could Not find Application';
        }else{
            app = applications[0];
        }
        
        contact borrowerContact = [SELECT id,name,
                                          clcommon__Current_State__c
                                   FROM contact
                                   WHERE AccountId = : app.genesis__account__r.id ];

        app.Proceeds_to_Customer__c = app.genesis__loan_amount__c;
        app.Total_Amount_being_Funded__c = app.genesis__loan_amount__c;
        Date systemDate = new loan.GlobalLoanUtilFacade().getCurrentSystemDate(); 
        if('Yes'.equalsIgnoreCase(app.Credit_Monitoring__c)){
            List<Ancillary_Product_Pricing_Detail__c> cmPricingDetails = [SELECT id, name,
                                                                                 Base__c,
                                                                                 Tax_percentage__c,
                                                                                 Tax_Amount__c      
                                                                          FROM Ancillary_Product_Pricing_Detail__c
                                                                          WHERE Ancillary_Product_Pricing_Header__r.Name = : 'CM'
                                                                          AND Region__c = : borrowerContact.clcommon__Current_State__c
                                                                          AND Effective_Date__c <= :systemDate 
                                                                          ORDER BY Effective_Date__c DESC];
                                                                          
            List<Period_Definition__mdt> periodDefinitions = [ SELECT 
                                                                    id,
                                                                    No_Of_Terms__c,
                                                                    Frequency__c
                                                                FROM 
                                                                    Period_Definition__mdt 
                                                            ];
            Map<String, Decimal> periodDefinitionMap = new Map<String, Decimal>();
            for ( Period_Definition__mdt period : periodDefinitions ) {
                periodDefinitionMap.put ( period.Frequency__c , period.No_Of_Terms__c ) ;
            }
            if(!cmPricingDetails.isEmpty()){
                Decimal periods = periodDefinitionMap.get(app.genesis__Payment_Frequency__c);     
                app.CM_Base_Amount__c = (cmPricingDetails[0].Base__c * 12)/periods;
                Decimal taxAmount = (cmPricingDetails[0].Base__c * cmPricingDetails[0].Tax_percentage__c) / 100;
                app.CM_Tax_Rate_Amount__c = ( taxAmount * 12 )/periods;
                app.Total_CM_Amount__c = app.CM_Base_Amount__c + app.CM_Tax_Rate_Amount__c;
                app.Proceeds_to_Customer__c = app.Proceeds_to_Customer__c - app.Total_CM_Amount__c;
               
            }    
            
        }else if('No'.equalsIgnoreCase(app.Credit_Monitoring__c)){
            app.CM_Base_Amount__c = 0;
            app.CM_Tax_Rate_Amount__c = 0;
            app.Total_CM_Amount__c = 0;
        }
        
        if('Yes'.equalsIgnoreCase(app.New_H_A__c)){
            List<Ancillary_Product_Pricing_Detail__c> haPricingDetails = [SELECT id, name,
                                                                          Base__c,
                                                                          Tax_percentage__c,
                                                                          Tax_Amount__c      
                                                                          FROM Ancillary_Product_Pricing_Detail__c
                                                                          WHERE Ancillary_Product_Pricing_Header__r.Name = : 'H&A'
                                                                          AND Region__c = : borrowerContact.clcommon__Current_State__c
                                                                          AND Term_Type__c = : app.Term_Type__c
                                                                          AND Term__c = : Double.ValueOf(app.Home_Auto_Term__c)
                                                                          AND H_A_Type__c = : app.H_A_Type__c];
            if(!haPricingDetails.isEmpty()){
                if(haPricingDetails[0].Base__c != null)
                    app.H_A_Plan_Base_Amount__c = haPricingDetails[0].Base__c;
                if(haPricingDetails[0].Tax_Amount__c != null)
                    app.H_A_Plan_Tax_Rate_Amount__c = haPricingDetails[0].Tax_Amount__c;
                app.Total_H_A_Plan_Amount__c = app.H_A_Plan_Base_Amount__c + app.H_A_Plan_Tax_Rate_Amount__c;
                if (app.H_A_Amount__c < app.Total_H_A_Plan_Amount__c){
                    app.Proceeds_to_Customer__c = (app.Proceeds_to_Customer__c + app.H_A_Amount__c ) - app.Total_H_A_Plan_Amount__c;
                    app.Total_Amount_being_Funded__c = ( app.Total_Amount_being_Funded__c + app.H_A_Amount__c );
                }else{
                    app.Proceeds_to_Customer__c = (app.Proceeds_to_Customer__c + app.H_A_Amount__c );
                    app.Total_Amount_being_Funded__c = ( app.Total_Amount_being_Funded__c + app.H_A_Amount__c );
                } 
            }   
        }else if('No'.equalsIgnoreCase(app.New_H_A__c)){
            app.H_A_Plan_Base_Amount__c = 0;
            app.H_A_Plan_Tax_Rate_Amount__c = 0;
            app.Total_H_A_Plan_Amount__c  = 0;
        }
        
        if('Accept'.equalsIgnoreCase(app.Loan_Protection_Plan__c)){
            List<Ancillary_Product_Pricing_Detail__c> llpPricingDetails = [SELECT id, name,
                                                                                  rate__c,
                                                                                  Tax_percentage__c,
                                                                                  Tax_Amount__c      
                                                                           FROM Ancillary_Product_Pricing_Detail__c
                                                                           WHERE Ancillary_Product_Pricing_Header__r.Name = : 'LPP'
                                                                           AND Region__c = : borrowerContact.clcommon__Current_State__c
                                                                           AND Effective_Date__c <= :systemDate
                                                                           AND Frequency__c = : app.genesis__Payment_Frequency__c
                                                                           AND loan_amount_to__c >= : app.genesis__loan_amount__c
                                                                           AND loan_amount_from__c <= : app.genesis__loan_amount__c 
                                                                           ORDER BY Effective_Date__c DESC];
            if(!llpPricingDetails.isEmpty()){
                Decimal estimatedInterest = (app.genesis__Total_Estimated_Interest__c != null ) ? app.genesis__Total_Estimated_Interest__c : 0;
                app.LPP_Base_Amount__c = (( app.genesis__loan_amount__c + estimatedInterest ) * llpPricingDetails[0].rate__c)/100;
                app.LPP_Tax_Rate_Amount__c = 0;
                if(llpPricingDetails[0].Tax_percentage__c != null){
                    app.LPP_Tax_Rate_Amount__c = (app.LPP_Base_Amount__c * llpPricingDetails[0].Tax_percentage__c)/100;
                }    
                app.Total_LPP_Amount__c = app.LPP_Base_Amount__c + app.LPP_Tax_Rate_Amount__c;
                app.Proceeds_to_Customer__c = app.Proceeds_to_Customer__c - app.Total_LPP_Amount__c;
            }
        }else if('Reject'.equalsIgnoreCase(app.Loan_Protection_Plan__c)){
            app.LPP_Base_Amount__c = 0;
            app.Total_LPP_Amount__c = 0;
            app.LPP_Tax_Rate_Amount__c = 0;
        }
        SecureDML.updateRecords(app);
        return 'Success';
    }
}