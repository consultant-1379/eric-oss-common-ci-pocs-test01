#!/bin/sh
#
# COPYRIGHT Ericsson 2021
#
#
#
# The copyright to the computer program(s) herein is the property of
#
# Ericsson Inc. The programs may be used and/or copied only with written
#
# permission from Ericsson Inc. or in accordance with the terms and
#
# conditions stipulated in the agreement/contract under which the
#
# program(s) have been supplied.
#

METRICS_EXPOSURE_TUTORIAL_URL="https://confluence-oss.seli.wh.rnd.internal.ericsson.com/pages/viewpage.action?spaceKey=ESO&title=How+to+add+metrics+to+a+microservice";

checkValuesYAML(){
    SERVICE_NAME=$1
    echo -e "prometheus:\n  path: /actuator/prometheus\n  scrape: true" > .bob/var.compareToLine;

    grep -A2 "^prometheus:" ./charts/$SERVICE_NAME/values.yaml > .bob/var.scrapedLine || true;

    if cmp -s .bob/var.compareToLine .bob/var.scrapedLine; then
        echo "SUCCESS: values.yaml contains all the lines necessary for metrics exposure.";
    else
        echo -e "FAILURE: This stage has failed as the lines needed for metric exposure are not correctly implemented inside values.yaml.\nPlease refer to the page provided:\n$METRICS_EXPOSURE_TUTORIAL_URL";
        echo -e "What is needed:"
        cat .bob/var.compareToLine
        echo -e "\nWhat was provided:"
        cat .bob/var.scrapedLine
        echo "ValuesYAML" >> .bob/var.metrics-exposed;
    fi
}

checkServiceYAML(){
    SERVICE_NAME=$1
    if grep -q "{{- include \"$SERVICE_NAME.annotations\" . | nindent [0-9] }}" ./charts/$SERVICE_NAME/templates/service.yaml &&
       grep -q "\"$SERVICE_NAME.prometheus\"" ./charts/$SERVICE_NAME/templates/_helpers.tpl; then
        echo "SUCCESS: service.yaml contains all the lines necessary for metrics exposure.";
    else
        echo -e "FAILURE: This stage has failed as the lines needed for metric exposure are not correctly implemented inside service.yaml.\nPlease refer to the page provided:\n$METRICS_EXPOSURE_TUTORIAL_URL";
        echo -e "What is needed:"
        echo -e "{{- include \"$SERVICE_NAME.annotations\" . | nindent [0-9] }} in service.yaml"
        echo -e "Where [0-9] is to be replaced by the indent number. Line has to be provided under 'annotations'."
        echo -e "and \"$SERVICE_NAME.prometheus\" in _helpers.tpl"
        echo "ServiceYAML" >> .bob/var.metrics-exposed;
    fi
}

checkDeploymentYAML(){
    SERVICE_NAME=$1
    if grep -q "{{- include \"$SERVICE_NAME.prometheus\" . | nindent [0-9] }}" ./charts/$SERVICE_NAME/templates/deployment.yaml; then
        echo "SUCCESS: deployment.yaml contains all the lines necessary for metrics exposure.";
    else
        echo -e "FAILURE: This stage has failed as the lines needed for metric exposure are not correctly implemented inside deployment.yaml.\nPlease refer to the page provided:\n$METRICS_EXPOSURE_TUTORIAL_URL";
        echo -e "What is needed:"
        echo -e "{{- include \"$SERVICE_NAME.prometheus\" . | nindent [0-9] }}"
        echo -e "Where [0-9] is to be replaced by the indent number."
        echo "DeploymentYAML" >> .bob/var.metrics-exposed;
    fi
}

checkConfigMapYAML(){
    SERVICE_NAME=$1
    if grep -q "{{- include \"$SERVICE_NAME.prometheus\" . | nindent [0-9] }}" ./charts/$SERVICE_NAME/templates/configmap.yaml; then
        echo "SUCCESS: configmap.yaml contains all the lines necessary for metrics exposure.";
    else
        echo -e "FAILURE: This stage has failed as the lines needed for metric exposure are not correctly implemented inside configmap.yaml.\nPlease refer to the page provided:\n$METRICS_EXPOSURE_TUTORIAL_URL";
        echo -e "What is needed:"
        echo -e "{{- include \"$SERVICE_NAME.prometheus\" . | nindent [0-9] }}"
        echo -e "Where [0-9] is to be replaced by the indent number."
        echo "ConfigMapYAML" >> .bob/var.metrics-exposed;
    fi
}

checkHelperTPL(){
    SERVICE_NAME=$1
    echo -e "{{/*\nCreate prometheus info\n*/}}" > .bob/var.compareToLine;
    echo -e "{{- define \"$SERVICE_NAME.prometheus\" -}}" >> .bob/var.compareToLine;
    echo -e "prometheus.io/path: {{ .Values.prometheus.path | quote }}" >> .bob/var.compareToLine;
    echo -e "prometheus.io/port: {{ .Values.service.port | quote }}" >> .bob/var.compareToLine;
    echo -e "prometheus.io/scrape: {{ .Values.prometheus.scrape | quote }}" >> .bob/var.compareToLine;
    echo -e "{{- end -}}" >> .bob/var.compareToLine;

    grep -B4 -A3 "^prometheus.io/path:" ./charts/$SERVICE_NAME/templates/_helpers.tpl > .bob/var.scrapedLine || true;

    if cmp -s .bob/var.compareToLine .bob/var.scrapedLine; then
        echo "SUCCESS: helper.yaml contains all the lines necessary for metrics exposure.";
    else
        echo -e "FAILURE: This stage has failed as the lines needed for metric exposure are not correctly implemented inside helper.tpl.\nPlease refer to the page provided:\n$METRICS_EXPOSURE_TUTORIAL_URL";
        echo -e "What is needed:"
        cat .bob/var.compareToLine
        echo -e "\nWhat was provided:"
        cat .bob/var.scrapedLine
        echo "HelperTPL" >> .bob/var.metrics-exposed;
    fi
}

checkPomXML(){
    echo -e "<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-core</artifactId>
    </dependency>
    <dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>" | sed 's/^[ \t]*//;s/[ \t]*$//' > .bob/var.compareToLine;

    grep -B2 -A7 "<artifactId>micrometer-core</artifactId>" ./pom.xml | sed 's/^[ \t]*//;s/[ \t]*$//' > .bob/var.scrapedLine || true;
    sort -u .bob/var.scrapedLine -o .bob/var.scrapedLine;
    sort -u .bob/var.compareToLine -o .bob/var.compareToLine;

    comm -23 .bob/var.compareToLine .bob/var.scrapedLine > .bob/var.dependancy;
    if [ -s ".bob/var.dependancy" ]
    then
        echo -e "FAILURE: This stage has failed as the lines needed for metric exposure are not correctly implemented inside pom.xml.\nPlease refer to the page provided:\n$METRICS_EXPOSURE_TUTORIAL_URL";
        echo -e "Dependancies needed:"
        cat .bob/var.compareToLine
        echo -e "\nWhat was provided:"
        cat .bob/var.scrapedLine
        echo "PomXML" >> .bob/var.metrics-exposed;
    else
        echo "SUCCESS: pom.xml contains all the lines necessary for metrics exposure.";
    fi
}

checkCoreApplicationJAVA(){

    echo -e "public RestTemplate restTemplate(final RestTemplateBuilder restTemplateBuilder)" > .bob/var.compareToLine;
    echo -e "return restTemplateBuilder.build()" >> .bob/var.compareToLine;

    find ./src/main/java -regex '.*Application.java' -exec grep -o 'public RestTemplate restTemplate(final RestTemplateBuilder restTemplateBuilder)' {} \; > .bob/var.scrapedLine || true;
    find ./src/main/java -regex '.*Application.java' -exec grep -o 'return restTemplateBuilder.build()' {} \; >> .bob/var.scrapedLine || true;

    if cmp -s .bob/var.compareToLine .bob/var.scrapedLine; then
        echo "SUCCESS: Core java application file contains all the lines necessary for metrics exposure.";
    else
        echo -e "FAILURE: This stage has failed as the lines needed for metric exposure are not correctly implemented inside the core java application file.\nPlease refer to the page provided:\n$METRICS_EXPOSURE_TUTORIAL_URL";
        echo -e "Please also ensure your main java file found in './src/main/java' follows the naming convention '<service-name>Application.java'"
        echo -e "What is needed:"
        cat .bob/var.compareToLine
        echo -e "\nWhat was provided:"
        cat .bob/var.scrapedLine
        echo "CoreApplicationJAVA" >> .bob/var.metrics-exposed;
    fi
}

passOrFailCheck(){
    if [ ! -s .bob/var.metrics-exposed ]; then
        echo "SUCCESS: All necessary lines for metrics exposure implemented correctly.";
    else
        for check in {"HelperTPL","CoreApplicationJAVA","PomXML","ValuesYAML","ConfigMapYAML"}
        do
            if grep -q "$check" .bob/var.metrics-exposed; then
               echo "FAILURE: Please review console output to find the files which should be corrected.";
               exit 1;
            fi
        done
        if grep -q "ServiceYAML" .bob/var.metrics-exposed && grep -q "DeploymentYAML" .bob/var.metrics-exposed; then
            echo "FAILURE: Please review console output to find the files which should be corrected.";
            exit 1;
        else
            echo "SUCCESS: All necessary lines for metrics exposure implemented correctly.";
        fi
    fi

}