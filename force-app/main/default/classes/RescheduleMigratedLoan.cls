public class RescheduleMigratedLoan {
    
    public loan__Loan_Account__c lAtobeUpdated;   
    Date repaymentStartDate;
    Date transactionDate;
    Id CLContractId;
    CL_Contract_Migration_Error_Log__c errorLogObject;
    Boolean useCustomLogging = false;

    loan__Batch_Process_Log__c batch = new loan__Batch_Process_Log__c();
    loan.globalLoanUtilFacade util = new loan.globalLoanUtilFacade();
    Date systemDate = util.getCurrentSystemDate();
       
    public RescheduleMigratedLoan(Id contractId,Date repaymentDate, Date txnDate){  
        CLContractId = contractId;
        repaymentStartDate = repaymentDate;
        transactionDate = txnDate;
    }
    
    //pallavi
    public RescheduleMigratedLoan(Id contractId){
        CLContractId = contractId;
    }
    //pallavi

    public RescheduleMigratedLoan(Id contractId, CL_Contract_Migration_Error_Log__c errorLogObject, Boolean useCustomLogging) {
        this.CLContractId = contractId;
        this.errorLogObject = errorLogObject;
        this.useCustomLogging = useCustomLogging;
        System.debug(logginglevel.error, ' In RescheduleMigratedLoan : LoanID: '+CLContractId +' ** errorLog :: '+errorLogObject +' ** logging :: '+useCustomLogging); 
    }
     
    
    public void rescheduleLoan() {               
        Date secondPaymentDate = null;
        Date lastPaymentDate; 
        Integer noOfInstallments = null;    
        Integer interestOnlyPeriod = null;  
        Decimal interestRate;
        String frequencyOfPayment;
        //Boolean maintainDelinquency = true; commented for goeasy
        Boolean maintainDelinquency = false;
        Boolean actualInterestOnlyPayments = true;
        Integer amortizationTerm;
        Integer dueDay;
        String stepUpOption = null;
        Decimal interestOnlyPaymentAmt = 0;
        Boolean regenerateInvAmzSchedule = false;
        
        try {      
                           
            if(lAtobeUpdated == null){
                lAtobeUpdated = [Select id,name,loan__First_Installment_Date__c,
                             Application__r.genesis__Monthly_Debt_Payments__c,
                             loan__Payment_Amount__c,
                             loan__Loan_Status__c,
                             loan__Accrual_Start_Date__c,
                             loan__Last_Installment_Date__c,
                             loan__Interest_Rate__c,
                             loan__Frequency_of_Loan_Payment__c,
                             loan__Pmt_Amt_Cur__c,
                             loan__Next_Installment_Date__c,
                             loan__Previous_Installment_Date__c,
                             loan__Maturity_Date_Current__c,
                             loan__Term_Cur__c,loan__Application_Date__c,                            
                             loan__Disbursal_Date__c,
                             loan__Interest_Only_Period__c,
                             (Select id,name,
                              loan__Is_Archived__c,
                              loan__Due_Date__c
                              from loan__Repayment_Schedule__r),
                             (select id,name from loan__Repayment_Plan__r)                              
                             from loan__Loan_Account__c
                             where Id =: CLContractId limit 1];
                       
            }
            
            System.debug('CLContractId..: '+CLContractId); 
            System.debug('loan__Maturity_Date_Current__c'+lAtobeUpdated.loan__Maturity_Date_Current__c);
                    
            if (lAtobeUpdated == null) {
                if (!useCustomLogging) {
                    batch.loan__Log_Level__c = 'ERROR';
                    batch.loan__Message__c = 'Please check the Lead Id as there are no contracts for the provided CLContractId ::'+ lAtobeUpdated.Name;                
                    batch.loan__Batch_Id__c = 'RescheduleMigratedLoan';
                    SecureDML.insertRecords(batch);
                } else {
                    errorLogObject.Schedule_generation_Error_Message__c = 'Please check the Lead Id as there are no contracts for the provided CLContractId ::'+ lAtobeUpdated.Name;
                }
                return;
            }

            if(repaymentStartDate == null){
                repaymentStartDate = lAtobeUpdated.loan__Next_Installment_Date__c;
            }
            if(transactionDate == null){
                transactionDate = systemDate;
            }
            interestOnlyPeriod = (Integer)lAtobeUpdated.loan__Interest_Only_Period__c;

            //set repayment date            
            
            system.debug('repaymentStartDate is: '+repaymentStartDate);
            
            Integer terms = 0;
             
            if(lAtobeUpdated.loan__Maturity_Date_Current__c != null){  
                lastPaymentDate = (lAtobeUpdated.loan__Maturity_Date_Current__c);
                terms = getRemainingTerm();
            }

            else{
                /*noOfInstallments = (Integer)lAtobeUpdated.loan__Term_Cur__c;
                terms = noOfInstallments;*/  //pallavi(temporarily commented)
                /*pallavi(temporarily added)*/
                lastPaymentDate = (lAtobeUpdated.loan__Last_Installment_Date__c);
                terms = getRemainingTerm();
                //noOfInstallments = terms;
                /*pallavi*/
            }

            interestRate = lAtobeUpdated.loan__Interest_Rate__c;
            frequencyOfPayment = lAtobeUpdated.loan__Frequency_of_Loan_Payment__c;
            if(repaymentStartDate != null){
                dueDay = repaymentStartDate.day();
            }
            System.debug(logginglevel.DEBUG,'Current Maturity Date: '+lastPaymentDate +' DUEDAY: '+dueDay);
                
            if(lAtobeUpdated.loan__Repayment_Plan__r != null && lAtobeUpdated.loan__Repayment_Plan__r.size() != 0) {
                delete lAtobeUpdated.loan__Repayment_Plan__r;
            }

            /*List<clcommon__Repayment_Plan__c> repaymentPlan = new List<clcommon__Repayment_Plan__c>(); 
            repaymentPlan.add(new clcommon__Repayment_Plan__c(clcommon__Sequence_Number__c = 1,
                                                              clcommon__Payment_Type__c = 'Equal Monthly Installments',
                                                              clcommon__Payment_Amount__c = lAtobeUpdated.loan__Pmt_Amt_Cur__c,                                                              
                                                              clcommon__Payment_Start_Date__c = repaymentStartDate,
                                                              clcommon__Number_Of_Payments__c = (terms - 1),
                                                              //clcommon__Due_Day__c = dueDay,
                                                              clcommon__Frequency__c = lAtobeUpdated.loan__Frequency_of_Loan_Payment__c,
                                                              clcommon__Frequency_Multiplier__c = 1,
                                                              clcommon__Effective_Date__c = systemDate,// can be transactionDate
                                                              loan__Loan_Account__c = lAtobeUpdated.id));
                                                              
            System.debug(logginglevel.DEBUG,'Repayment PLAN :: '+repaymentPlan);*/
            //insert repaymentPlan;
            
            //pallavi(to keep same current payment amount)
            Map<String, Object> rescheduleParametersmap = new Map<String, Object>();
            rescheduleParametersmap.put('Payment_Amount__c',lAtobeUpdated.loan__Pmt_Amt_Cur__c);
            rescheduleParametersmap.put('Same_Monthly_Payment__c',true);
            rescheduleParametersmap.put('Reschedule_Balance__c','Principal Remaining');
            rescheduleParametersmap.put('Schedule_Adjustment_Method__c','After');
            rescheduleParametersmap.put('Move_Across_Months__c',true);
            
            //pallavi
            
            loan.LoanRescheduleParameters rescheduleParams = new loan.LoanRescheduleParameters(lAtobeUpdated.id,
                                                                                               transactionDate,
                                                                                               repaymentStartDate,
                                                                                               secondPaymentDate,
                                                                                               lastPaymentDate,
                                                                                               noOfInstallments,
                                                                                               interestOnlyPeriod,
                                                                                               interestRate,
                                                                                               frequencyOfPayment,
                                                                                               maintainDelinquency,
                                                                                               actualInterestOnlyPayments,
                                                                                               amortizationTerm,
                                                                                               dueDay,
                                                                                               stepUpOption,
                                                                                               interestOnlyPaymentAmt,
                                                                                               regenerateInvAmzSchedule,
                                                                                               rescheduleParametersmap); //pallavi(to keep same current payment amount)

            List<loan.LoanRescheduleParameters.ProposedRepaymentPlan> repaymentPlanList = rescheduleParams.getRepaymentPlan();
            System.debug(logginglevel.DEBUG,'repaymentPlanList.. : '+repaymentPlanList);
            rescheduleParams.setRepaymentPlan(repaymentPlanList);
            System.debug(logginglevel.DEBUG,'After repaymentPlanList.. : '+repaymentPlanList);
            loan.LoanActionFactory factory = new loan.LoanActionFactory();
            loan.LoanAction7 loanAction = factory.getLoanAction7API();
            System.debug(logginglevel.DEBUG,'rescheduleParams.. : '+rescheduleParams);
            loan__Loan_Account__c systemUpdateClLoan = loanAction.rescheduleALoan(rescheduleParams);            
            System.debug(logginglevel.DEBUG, 'systemUpdateClLoan ' + systemUpdateClLoan);
            //check if reschedule is successful
            
            System.debug('Call to rescheduleALoan of loanAction ends..');
            
            lAtobeUpdated.loan__Maturity_Date_Current__c = systemUpdateClLoan.loan__Maturity_Date_Current__c;
            lAtobeUpdated.loan__Draw_Period_End_Date__c = systemUpdateClLoan.loan__Maturity_Date_Current__c;
            if((lAtobeUpdated.loan__Loan_Status__c).equals('Active - Good Standing')){
                lAtobeUpdated.loan__Oldest_Due_Date__c = repaymentStartDate;
                System.debug('loan__Oldest_Due_Date__c is updated to: '+lAtobeUpdated.loan__Oldest_Due_Date__c);
            }
            
            SecureDML.updateRecords(lAtobeUpdated);  
            System.debug('After update :: ' + lAtobeUpdated);

        } catch (Exception e) {          
            if (!useCustomLogging) {
                batch.loan__Log_Level__c = 'ERROR';
                batch.loan__Message__c = ' Reschedule Failed for ::'+ lAtobeUpdated.Name + '. :: ERROR :: '+e.getMessage() + ' :: StackTrace ::' +e.getStackTraceString() ;
                batch.loan__Batch_Id__c = 'RescheduleMigratedLoan';
                SecureDML.insertRecords(batch);
            } /*else {	//pallavi(commented to handle exception throw in LoadContractWrapper)
                errorLogObject.Schedule_generation_Error_Message__c = 'Reschedule Failed for ::'+ lAtobeUpdated.Name + '. :: ERROR :: '+e.getMessage() + ' :: StackTrace ::' +e.getStackTraceString();
                if (null != errorLogObject.Id) {
                    SecureDML.updateRecords(errorLogObject);
                } else {
                    SecureDML.insertRecords(errorLogObject);
                }
            }*/
            System.debug(logginglevel.error,'line number'+e.getLineNumber());
            System.debug(logginglevel.error,'error stackTrace'+e.getStackTraceString());
            System.debug(logginglevel.error,'error message'+e.getMessage() + e.getLineNumber());
			throw e;	//pallavi (throws exception so that contracts get rolled back)
        }
        
    }

    /*
     *  Calculates remaining number of payments to be done
     *  returns integer 
     * 
     */
    public Integer getRemainingTerm() {
    
        Integer remainingTerm;
        if (lAtobeUpdated.loan__Maturity_Date_Current__c != null) { 
            remainingTerm = (Integer)(loan.DateUtil.cyclesBetween(transactionDate, //lAtobeUpdated.loan__Next_Installment_Date__c,
                                                                  lAtobeUpdated.loan__Maturity_Date_Current__c,
                                                                  lAtobeUpdated.loan__Frequency_of_Loan_Payment__c));
                                                                  
            System.debug(logginglevel.error,'remainingTerm in IF :: '+remainingTerm);
        }
            
         /*pallavi*/
            else{
                 remainingTerm = (Integer)(loan.DateUtil.cyclesBetween(transactionDate,
                                                                  lAtobeUpdated.loan__Last_Installment_Date__c,
                                                                  lAtobeUpdated.loan__Frequency_of_Loan_Payment__c));
                                                                  
            System.debug(logginglevel.error,'remainingTerm in IF :: '+remainingTerm);
            }  
         /*pallavi*/   
        System.debug(logginglevel.error,'remainingTerm ::'+remainingTerm);
        return remainingTerm;
    }
    
}