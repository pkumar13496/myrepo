@isTest private class ApplicationHistoryControllerTest {
    @isTest private static void returnsHistoryData() {
        TestHistoryService applicationHistoryService = new TestHistoryService();
        applicationHistoryService.data.eventHistory.add(new TestHistoryDataItem());
        applicationHistoryService.data.chatterHistory.add(new TestHistoryDataItem());
        applicationHistoryService.data.chatterComments.add(new TestHistoryDataItem());

        ApplicationHistoryController.ApplicationHistoryData data = ApplicationHistoryController.search(applicationHistoryService, '123');

        System.assertEquals(1, data.eventHistory.size());
        System.assertEquals(1, data.chatterHistory.size());
        System.assertEquals(1, data.chatterComments.size());
    }

    private class TestHistoryService implements Service.ApplicationHistory {
        public TestHistoryData data = new TestHistoryData();

        public Service.ApplicationHistoryData getLegacyData(String applicationId) {
            return data;
        }
    }

    private class TestHistoryData implements Service.ApplicationHistoryData {
        public List<Service.ApplicationHistoryDataItem> eventHistory = new List<Service.ApplicationHistoryDataItem>();
        public List<Service.ApplicationHistoryDataItem> chatterHistory = new List<Service.ApplicationHistoryDataItem>();
        public List<Service.ApplicationHistoryDataItem> chatterComments = new List<Service.ApplicationHistoryDataItem>();

        public List<Service.ApplicationHistoryDataItem> getEventHistory() {
            return eventHistory;
        }

        public List<Service.ApplicationHistoryDataItem> getChatterHistory() {
            return chatterHistory;
        }

        public List<Service.ApplicationHistoryDataItem> getChatterComments() {
            return chatterComments;
        }
    }

    private class TestHistoryDataItem implements Service.ApplicationHistoryDataItem {
        public Date getDate() {
            return Date.newInstance(2019, 03, 15);
        }

        public String getMessage() {
            return 'msg';
        }

        public String getUserName() {
            return 'usr';
        }

        public String getStatus() {
            return 'status';
        }
    }
}