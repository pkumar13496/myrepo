public with sharing class ApplicationHistoryController {
    @AuraEnabled public static ApplicationHistoryData search(String applicationId) {
        return search(new ServiceMulesoftApplicationHistory(), applicationId);
    }

    @testVisible private static ApplicationHistoryData search(Service.ApplicationHistory applicationHistoryService, String applicationId) {
        Service.ApplicationHistoryData historyData = applicationHistoryService.getLegacyData(applicationId);
        ApplicationHistoryData applicationHistoryData = new ApplicationHistoryData();
        for (Service.ApplicationHistoryDataItem historyDataItem : historyData.getEventHistory()) {
            applicationHistoryData.eventHistory.add(new ApplicationHistoryDataItem(historyDataItem));
        }
        for (Service.ApplicationHistoryDataItem historyDataItem : historyData.getChatterHistory()) {
            applicationHistoryData.chatterHistory.add(new ApplicationHistoryDataItem(historyDataItem));
        }
        for (Service.ApplicationHistoryDataItem historyDataItem : historyData.getChatterComments()) {
            applicationHistoryData.chatterComments.add(new ApplicationHistoryDataItem(historyDataItem));
        }
        return applicationHistoryData;
    }



    public class ApplicationHistoryData {
        @AuraEnabled public List<ApplicationHistoryDataItem> eventHistory;
        @AuraEnabled public List<ApplicationHistoryDataItem> chatterHistory;
        @AuraEnabled public List<ApplicationHistoryDataItem> chatterComments;

        public ApplicationHistoryData() {
            eventHistory = new List<ApplicationHistoryDataItem>();
            chatterHistory = new List<ApplicationHistoryDataItem>();
            chatterComments = new List<ApplicationHistoryDataItem>();
        }
    }

    public class ApplicationHistoryDataItem {
        @AuraEnabled public String itemDate;
        @AuraEnabled public String message;
        @AuraEnabled public String userName;
        @AuraEnabled public String status;

        public ApplicationHistoryDataItem(Service.ApplicationHistoryDataItem item) {
            itemDate = item.getDate().format();
            message = item.getMessage();
            userName = item.getUserName();
            status = item.getStatus();
        }
    }
}