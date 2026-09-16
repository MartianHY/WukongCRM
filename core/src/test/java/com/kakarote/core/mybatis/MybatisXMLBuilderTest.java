package com.kakarote.core.mybatis;

import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.mapping.BoundSql;
import org.apache.ibatis.session.Configuration;
import org.junit.Test;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class MybatisXMLBuilderTest {

    @Test
    public void customForUsesValidForeachElementAndKeepsEmptyCollectionFallback() {
        Configuration configuration = new Configuration();
        configuration.setDefaultScriptingLanguage(MybatisXMLDriver.class);

        String mapper = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                + "<!DOCTYPE mapper PUBLIC \"-//mybatis.org//DTD Mapper 3.0//EN\" \"http://mybatis.org/dtd/mybatis-3-mapper.dtd\">\n"
                + "<mapper namespace=\"test.CustomForMapper\">\n"
                + "  <select id=\"selectIds\" resultType=\"long\">\n"
                + "    SELECT id FROM test_table WHERE id IN\n"
                + "    <foreach collection=\"__wk_for__:ids\" item=\"id\">#{id}</foreach>\n"
                + "  </select>\n"
                + "</mapper>";

        XMLMapperBuilder mapperBuilder = new XMLMapperBuilder(
                new ByteArrayInputStream(mapper.getBytes(StandardCharsets.UTF_8)),
                configuration,
                "custom-for-test.xml",
                configuration.getSqlFragments());
        mapperBuilder.parse();

        Map<String, Object> emptyParams = new HashMap<>();
        emptyParams.put("ids", Collections.emptyList());
        BoundSql emptyBoundSql = configuration
                .getMappedStatement("test.CustomForMapper.selectIds")
                .getBoundSql(emptyParams);

        String normalizedSql = emptyBoundSql.getSql().replaceAll("\\s+", " ").trim();
        assertTrue(normalizedSql, normalizedSql.endsWith("IN ( ? )"));
        assertEquals(1, emptyBoundSql.getParameterMappings().size());

        Map<String, Object> stringParams = new HashMap<>();
        stringParams.put("ids", "10,20");
        BoundSql stringBoundSql = configuration
                .getMappedStatement("test.CustomForMapper.selectIds")
                .getBoundSql(stringParams);
        assertEquals(2, stringBoundSql.getParameterMappings().size());
    }
}
